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

local function resolve_cmd(cmd, source, target)
	local function resolve(value, resolved_source, resolved_target)
		if target == nil then
			assert(not value:find("{target}", 1, true), "Task command references {target} without defining target")
			return (value:gsub("{source}", resolved_source))
		end
		return (value:gsub("{source}", resolved_source):gsub("{target}", resolved_target))
	end

	if vim.islist(cmd) then
		return vim.tbl_map(function(value)
			return resolve(value, source, target)
		end, cmd)
	end
	return resolve(cmd, quoted_path(source), target and quoted_path(target) or nil)
end

local function build_task(task, source, target, project, branch, current_cwd)
	local cwd = task.fork == true and vim.fs.joinpath(dirs.projects, project, branch) or current_cwd
	local result = vim.deepcopy(task)
	result.name = nil
	result.source = nil
	result.target = nil
	result.cmd = resolve_cmd(task.cmd, vim.fs.abspath(source), target and vim.fs.abspath(target) or nil)
	result.cwd = cwd
	return result
end

local function validate_task(task)
	assert(type(task.name) == "string", "Task name must be a string")
	assert(type(task.source) == "string", string.format("Task %s source must be a string", task.name))
	assert(
		task.target == nil or type(task.target) == "string",
		string.format("Task %s target must be a string", task.name)
	)
	assert(
		type(task.cmd) == "string" or vim.islist(task.cmd),
		string.format("Task %s cmd must be a string or list", task.name)
	)
end

local function source_details(source, task)
	local relative = assert(vim.fs.relpath(dirs.artifacts, source))
	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local project, branch = parts[1], parts[2]
	assert(project and branch, "Artifact task must be inside a project branch")
	if #parts == 2 then
		branch = branch:match("^(.*)%." .. vim.pesc(task.source) .. "$")
			or (branch == task.source and (config.default_branches)[1])
		assert(branch, "Project-level artifact must be a task source or encode its branch")
	end

	local filename = vim.fs.basename(source)
	local identifier = filename == task.source and vim.fs.basename(vim.fs.dirname(source))
		or assert(filename:match("^(.*)%." .. vim.pesc(task.source) .. "$"))
	return project, branch, identifier
end

local function definition(task, source, cwd)
	local project, branch, identifier = source_details(source, task)
	local target = task.target and vim.fs.joinpath(vim.fs.dirname(source), task.target) or nil
	return {
		name = table.concat({ task.name, branch, identifier }, ":"),
		builder = function()
			return build_task(task, source, target, project, branch, cwd)
		end,
	}
end

local function task_matches_source(task, source)
	local filename = vim.fs.basename(source)
	return filename == task.source or (task.target == nil and vim.endswith(filename, "." .. task.source))
end

local function is_available(task, source, checkout_branch)
	local _, branch = source_details(source, task)
	local target = task.target and vim.fs.joinpath(vim.fs.dirname(source), task.target) or nil
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
	for _, task in ipairs(opts.tasks or {}) do
		validate_task(task)
		if task_matches_source(task, source) and is_available(task, source, checkout_branch) then
			table.insert(definitions, definition(task, source, cwd))
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

	local indexed_files = require("neoterm.artifact_tasks").files(artifact_dir)
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
			for _, task in ipairs(opts.tasks or {}) do
				validate_task(task)
				for _, source in ipairs(indexed_files) do
					if task_matches_source(task, source) then
						local _, branch = source_details(source, task)
						local target = task.target and vim.fs.joinpath(vim.fs.dirname(source), task.target) or nil
						if
							(is_default_branch(checkout_branch) or branch == checkout_branch)
							and (target == nil or not present[target])
						then
							table.insert(definitions, definition(task, source, cwd))
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
