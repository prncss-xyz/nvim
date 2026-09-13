local parameters = require("my.parameters")
local dirs = parameters.dirs

local function default_checkout(project)
	local project_dir = vim.fs.joinpath(dirs.projects, project)
	for _, branch in ipairs(parameters.default_branches or { "main", "master" }) do
		local checkout = vim.fs.joinpath(project_dir, branch)
		if vim.fn.isdirectory(checkout) == 1 then
			return checkout
		end
	end
	error("Could not find a default checkout for " .. project)
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

local function build_task(task, source, target, project)
	local cwd = default_checkout(project)
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
				local relative = vim.fs.relpath(dirs.artifacts, vim.fs.joinpath(path, name))
				local parts = relative and vim.split(relative, "/", { plain = true, trimempty = true }) or {}
				return task.target == nil and #parts == 2 and vim.endswith(name, "." .. task.source)
			end, {
				path = dirs.artifacts,
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

				local target = task.target and vim.fs.joinpath(vim.fs.dirname(source), task.target) or nil
				if target == nil or vim.fn.filereadable(target) == 0 then
					table.insert(definitions, {
						name = branch .. ":" .. task.name,
						builder = function()
							return build_task(task, source, target, project)
						end,
					})
				end
			end
		end
		return definitions
	end,
}
