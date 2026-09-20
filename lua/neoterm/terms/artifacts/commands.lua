local config = require("neoterm.config")
local dirs = config.dirs

local M = {}

local function current_branch(cwd)
	local branch = vim.trim(vim.fn.system({ "git", "-C", cwd, "branch", "--show-current" }))
	if vim.v.shell_error == 0 and branch ~= "" then
		return branch
	end
end

local function is_default_branch(branch)
	return branch == nil or vim.tbl_contains(config.default_branches, branch)
end

local function current_project(cwd)
	local relative = vim.fs.relpath(dirs.projects, vim.fs.abspath(cwd))
	if relative == nil then
		return nil
	end
	return vim.split(relative, "/", { plain = true, trimempty = true })[1]
end

local function quoted_path(path)
	local home = vim.fs.normalize(vim.env.HOME)
	path = vim.fs.normalize(path)
	if path == home then
		path = "~"
	elseif vim.startswith(path, home .. "/") then
		path = "~" .. path:sub(#home + 1)
	end
	return '"' .. path .. '"'
end

local function resolve_command(command, source, target, step)
	local resolved_source = quoted_path(source)
	local resolved_target = target and quoted_path(target) or nil
	local function resolve(value)
		if type(value) == "table" then
			local result = {}
			for key, item in pairs(value) do
				result[key] = resolve(item)
			end
			return result
		end
		if type(value) ~= "string" then
			return value
		end
		if target == nil then
			assert(not value:find("{target}", 1, true), "Step command references {target} without defining target")
			return (value:gsub("{source}", resolved_source):gsub("{step}", step))
		end
		return (value:gsub("{source}", resolved_source):gsub("{target}", resolved_target):gsub("{step}", step))
	end
	return resolve(command)
end

local function build_step(step, source, target, project, branch, current_cwd, name)
	local cwd = step.fork == true and vim.fs.joinpath(dirs.projects, project, branch) or current_cwd
	local result = resolve_command(step.command, vim.fs.abspath(source), target and vim.fs.abspath(target) or nil, name)
	if type(result) == "string" then
		result = { cmd = result }
	end
	result.cwd = result.cwd or cwd
	return result
end

local function validate_step(step)
	assert(type(step.name) == "string", "Step name must be a string")
	assert(type(step.source) == "string", string.format("Step %s source must be a string", step.name))
	assert(
		step.target == nil or type(step.target) == "string",
		string.format("Step %s target must be a string", step.name)
	)
	assert(
		type(step.command) == "string" or type(step.command) == "table",
		string.format("Step %s command must be a string or table", step.name)
	)
end

local function source_details(source, step)
	local relative = assert(vim.fs.relpath(dirs.artifacts, source))
	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local project, branch = parts[1], parts[2]
	assert(project and branch, "Artifact step must be inside a project branch")
	if #parts == 2 then
		branch = branch:match("^(.*)%." .. vim.pesc(step.source) .. "$")
			or (branch == step.source and (config.default_branches)[1])
		assert(branch, "Project-level artifact must be a step source or encode its branch")
	end

	local filename = vim.fs.basename(source)
	local identifier = filename == step.source and vim.fs.basename(vim.fs.dirname(source))
		or assert(filename:match("^(.*)%." .. vim.pesc(step.source) .. "$"))
	return project, branch, identifier
end

local function definition(step, source, cwd)
	local project, branch, identifier = source_details(source, step)
	local target = step.target and vim.fs.joinpath(vim.fs.dirname(source), step.target) or nil
	local name = table.concat({ step.name, branch, identifier }, ":")
	return {
		name = name,
		builder = function()
			return build_step(step, source, target, project, branch, cwd, name)
		end,
	}
end

local function step_matches_source(step, source)
	local filename = vim.fs.basename(source)
	return filename == step.source or (step.target == nil and vim.endswith(filename, "." .. step.source))
end

local function is_available(step, source, checkout_branch)
	local _, branch = source_details(source, step)
	local target = step.target and vim.fs.joinpath(vim.fs.dirname(source), step.target) or nil
	return (is_default_branch(checkout_branch) or branch == checkout_branch)
		and (target == nil or vim.fn.filereadable(target) == 0)
end

function M.for_file(opts)
	local definitions = {}
	local cwd = opts.cwd or vim.fn.getcwd()
	local project = current_project(cwd)
	local source = vim.fs.abspath(opts.file)
	local artifact_dir = project and vim.fs.joinpath(dirs.artifacts, project) or nil
	if artifact_dir == nil or vim.fs.relpath(artifact_dir, source) == nil or vim.fn.filereadable(source) == 0 then
		return definitions
	end

	local checkout_branch = current_branch(cwd)
	for _, step in ipairs(opts.steps or {}) do
		validate_step(step)
		if step_matches_source(step, source) and is_available(step, source, checkout_branch) then
			table.insert(definitions, definition(step, source, cwd))
		end
	end
	return definitions
end

function M.generator(opts, callback)
	local definitions = {}
	local cwd = opts.cwd or opts.dir or vim.fn.getcwd()
	local project = current_project(cwd)
	if project == nil then
		return vim.schedule(function()
			callback(definitions)
		end)
	end
	local artifact_dir = vim.fs.joinpath(dirs.artifacts, project)

	local indexed_files = require("neoterm.terms.artifacts.tasks").files(artifact_dir)
	local present = {}
	for _, path in ipairs(indexed_files) do
		present[path] = true
	end
	vim.system(
		{ "git", "-C", cwd, "branch", "--show-current" },
		{ text = true },
		vim.schedule_wrap(function(result)
			local checkout_branch = result.code == 0 and vim.trim(result.stdout or "") or nil
			if checkout_branch == "" then
				checkout_branch = nil
			end
			for _, step in ipairs(opts.steps or {}) do
				validate_step(step)
				for _, source in ipairs(indexed_files) do
					if step_matches_source(step, source) then
						local _, branch = source_details(source, step)
						local target = step.target and vim.fs.joinpath(vim.fs.dirname(source), step.target) or nil
						if
							(is_default_branch(checkout_branch) or branch == checkout_branch)
							and (target == nil or not present[target])
						then
							table.insert(definitions, definition(step, source, cwd))
						end
					end
				end
			end
			table.sort(definitions, function(a, b)
				return a.name < b.name
			end)
			callback(definitions)
		end)
	)
end

return M
