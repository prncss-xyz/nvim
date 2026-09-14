local parameters = require("my.parameters")
local dirs = parameters.dirs

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

return {
	generator = function(opts)
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
			assert(type(task.name) == "string", "Task name must be a string")
			assert(type(task.source) == "string", string.format("Task %s source must be a string", task.name))
			assert(
				task.target == nil or type(task.target) == "string",
				string.format("Task %s target must be a string", task.name)
			)
			assert(type(task.cmd) == "string", string.format("Task %s cmd must be a string", task.name))

			local sources = vim.fs.find(function(name, path)
				if name == task.source then
					return true
				end
				return task.target == nil and vim.endswith(name, "." .. task.source)
			end, {
				path = artifact_dir,
				type = "file",
				limit = math.huge,
			})
			table.sort(sources)

			for _, source in ipairs(sources) do
				local relative = assert(vim.fs.relpath(dirs.artifacts, source))
				local parts = vim.split(relative, "/", { plain = true, trimempty = true })
				local project, branch = parts[1], parts[2]
				assert(project and branch, "Artifact task must be inside a project branch")
				if #parts == 2 then
					branch = assert(branch:match("^(.*)%." .. vim.pesc(task.source) .. "$"))
				end

				local filename = vim.fs.basename(source)
				local identifier = filename == task.source and vim.fs.basename(vim.fs.dirname(source))
					or assert(filename:match("^(.*)%." .. vim.pesc(task.source) .. "$"))
				local target = task.target and vim.fs.joinpath(vim.fs.dirname(source), task.target) or nil
				local matches_checkout = is_default_branch(checkout_branch) or branch == checkout_branch
				if matches_checkout and (target == nil or vim.fn.filereadable(target) == 0) then
					table.insert(definitions, {
						name = table.concat({ task.name, branch, identifier }, ":"),
						builder = function()
							return build_task(task, source, target, project, branch, cwd)
						end,
					})
				end
			end
		end
		return definitions
	end,
}
