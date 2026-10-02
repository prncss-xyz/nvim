local config = require("neoterm.config")
local dirs = config.dirs

local M = {}

local function apply_template(t, vars)
	if type(t) == "function" then
		return t(vars)
	end
	return (
		string.gsub(t, "{(.-)}", function(key)
			return assert(vars[key], "unknown template variable: " .. key)
		end)
	)
end

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

local function resolve_command(command, source, target, step, variant)
	local vars = {
		source = quoted_path(source),
		target = target and quoted_path(target) or nil,
		step = step,
		variant = variant,
	}
	local function resolve(value)
		if type(value) == "function" then
			return resolve(apply_template(value, vars))
		end
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
		end
		return apply_template(value, vars)
	end
	return resolve(command)
end

local function build_step(step, source, target, project, branch, current_cwd, name, variant)
	local cwd = step.fork == true and vim.fs.joinpath(dirs.projects, project, branch) or current_cwd
	local result =
		resolve_command(step.command, vim.fs.abspath(source), target and vim.fs.abspath(target) or nil, name, variant)
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
		type(step.command) == "string" or type(step.command) == "table" or type(step.command) == "function",
		string.format("Step %s command must be a string, table, or function", step.name)
	)
	assert(
		step.variants == nil or type(step.variants) == "table",
		string.format("Step %s variants must be a table", step.name)
	)
	for _, variant in ipairs(step.variants or {}) do
		assert(type(variant) == "string", string.format("Step %s variants must be strings", step.name))
	end
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

local function definition(step, source, cwd, variant)
	local project, branch, identifier = source_details(source, step)
	local target = step.target and vim.fs.joinpath(vim.fs.dirname(source), step.target) or nil
	local name_parts = { step.name }
	if variant then
		table.insert(name_parts, variant)
	end
	table.insert(name_parts, branch)
	if vim.fs.basename(source) == step.source or identifier ~= branch then
		table.insert(name_parts, identifier)
	end
	local name = table.concat(name_parts, ":")
	local task = build_step(step, source, target, project, branch, cwd, name, variant)
	task.name = name
	return task
end

local function executable_definition(path, cwd)
	local relative = assert(vim.fs.relpath(dirs.artifacts, path), "Executable must be inside the artifact directory")
	local name = "script:" .. vim.fs.dirname(relative) .. " " .. vim.fs.basename(relative)
	return { name = name, cmd = { path }, cwd = cwd, exit_policy = "keep" }
end

local function add_task_executables(definitions, task_source, cwd, checkout_branch, executables)
	if vim.fs.basename(task_source) ~= "task.md" then
		return
	end
	local _, branch = source_details(task_source, { source = "task.md" })
	if not is_default_branch(checkout_branch) and branch ~= checkout_branch then
		return
	end
	local task_dir = vim.fs.dirname(task_source)
	for _, path in ipairs(executables) do
		if vim.fs.dirname(path) == task_dir then
			table.insert(definitions, executable_definition(path, cwd))
		end
	end
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
			if step.variants then
				for _, variant in ipairs(step.variants) do
					table.insert(definitions, definition(step, source, cwd, variant))
				end
			else
				table.insert(definitions, definition(step, source, cwd))
			end
		end
	end
	add_task_executables(
		definitions,
		source,
		cwd,
		checkout_branch,
		require("neoterm.terms.artifacts.tasks").executables(vim.fs.dirname(source))
	)
	return definitions
end

function M.select_for_current_file(resume)
	local file = vim.api.nvim_buf_get_name(0)
	local cwd = require("neoterm.terms.artifacts.cwd").context_dir() or vim.fn.getcwd()
	local steps = config.steps
	if resume then
		steps = vim.tbl_filter(function(step)
			return type(step.command) == "table" and step.command.tag == "agent"
		end, steps)
	end
	local definitions = M.for_file({
		cwd = cwd,
		file = file,
		steps = steps,
	})
	if not resume and vim.fn.filereadable(file) == 1 and vim.fn.executable(file) == 1 then
		table.insert(definitions, { name = "exec", cmd = { vim.fs.abspath(file) }, cwd = cwd })
	end
	if resume then
		definitions = vim.tbl_filter(function(item)
			return item.tag == "agent"
		end, definitions)
		for index, item in ipairs(definitions) do
			definitions[index] = {
				tag = item.tag,
				title = item.title,
				agent = item.agent,
				resume = true,
				name = item.name,
				cwd = item.cwd,
			}
		end
	end
	vim.ui.select(definitions, {
		prompt = resume and "Resume Buffer Step: " or "Start Buffer Step: ",
		format_item = function(definition_)
			return definition_.name
		end,
	}, function(definition_)
		if definition_ == nil then
			return
		end
		definition_.key = definition_.name
		definition_.display_name = definition_.name
		definition_.exit_policy = definition_.exit_policy or "close"
		require("neoterm.terms").start(definition_)
	end)
end

return M
