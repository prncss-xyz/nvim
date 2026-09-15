local parameters = require("my.parameters")
local dirs = parameters.dirs

local M = {}

local function current_branch(cwd)
	local branch = vim.trim(vim.fn.system({ "git", "-C", cwd, "branch", "--show-current" }))
	if vim.v.shell_error == 0 and branch ~= "" then
		return branch
	end
end

local function is_default_branch(branch)
	return branch == nil or vim.tbl_contains(parameters.default_branches or { "main", "master" }, branch)
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
	if target == nil then
		assert(not cmd:find("{target}", 1, true), "Task command references {target} without defining target")
		return (cmd:gsub("{source}", quoted_path(source)))
	end
	return (cmd:gsub("{source}", quoted_path(source)):gsub("{target}", quoted_path(target)))
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
	assert(type(task.cmd) == "string", string.format("Task %s cmd must be a string", task.name))
end

local function source_details(source, task)
	local relative = assert(vim.fs.relpath(dirs.artifacts, source))
	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local project, branch = parts[1], parts[2]
	assert(project and branch, "Artifact task must be inside a project branch")
	if #parts == 2 then
		branch = branch:match("^(.*)%." .. vim.pesc(task.source) .. "$")
			or (branch == task.source and (parameters.default_branches or { "main", "master" })[1])
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
	local cwd = opts.dir or vim.fn.getcwd()
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

function M.generator(opts)
	local definitions = {}
	local cwd = opts.dir or vim.fn.getcwd()
	local project = current_project(cwd)
	if project == nil then
		return definitions
	end
	local artifact_dir = vim.fs.joinpath(dirs.artifacts, project)
	if vim.fn.isdirectory(artifact_dir) == 0 then
		return definitions
	end

	local checkout_branch = current_branch(cwd)
	for _, task in ipairs(opts.tasks or {}) do
		validate_task(task)
		local sources = vim.fs.find(function(name)
			return name == task.source or (task.target == nil and vim.endswith(name, "." .. task.source))
		end, {
			path = artifact_dir,
			type = "file",
			limit = math.huge,
		})
		table.sort(sources)

		for _, source in ipairs(sources) do
			if is_available(task, source, checkout_branch) then
				table.insert(definitions, definition(task, source, cwd))
			end
		end
	end
	return definitions
end

return M
