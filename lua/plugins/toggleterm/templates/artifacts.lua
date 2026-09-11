local parameters = require("my.parameters")
local dirs = parameters.dirs

local function default_checkout(repo_dir)
	for _, branch in ipairs(parameters.default_branches) do
		local checkout = vim.fs.joinpath(repo_dir, branch)
		if vim.fn.isdirectory(checkout) == 1 then
			return checkout
		end
	end
	error("Could not find a main or master checkout for " .. repo_dir)
end

local function add_definition(definitions, opts)
	table.insert(definitions, {
		name = opts.name,
		builder = function()
			return {
				cmd = string.format(opts.cmd, opts.path),
				cwd = opts.cwd,
			}
		end,
	})
end

return {
	generator = function(opts)
		local definitions = {}
		local tasks_by_source = {}
		for _, task in ipairs(opts.tasks or {}) do
			assert(type(task.source) == "string", "Task source must be a string")
			assert(type(task.cmd) == "string", string.format("Task %s cmd must be a string", task.source))
			assert(
				task.fork == nil or type(task.fork) == "boolean",
				string.format("Task %s fork must be a boolean", task.source)
			)
			tasks_by_source[task.source] = tasks_by_source[task.source] or {}
			table.insert(tasks_by_source[task.source], task)
		end

		local files = vim.fs.find(function(name)
			return name:match("%.md$") ~= nil
		end, { path = dirs.artifacts, type = "file", limit = math.huge })
		table.sort(files)

		for _, path in ipairs(files) do
			local relative = vim.fs.relpath(dirs.artifacts, path)
			local repo, branch, task
			if relative then
				repo, branch, task = relative:match("^([^/]+)/([^/]+)/([^/]+)%.md$")
			end
			local matching_tasks = task and tasks_by_source[task]
			if matching_tasks then
				local absolute_path = vim.fs.abspath(path)
				local name = string.format("%s (%s/%s)", task, repo, branch)
				for index, matching_task in ipairs(matching_tasks) do
					local cwd = matching_task.fork == false and default_checkout(vim.fs.joinpath(dirs.projects, repo))
						or vim.fs.joinpath(dirs.projects, repo, branch)
					add_definition(definitions, {
						name = #matching_tasks == 1 and name or string.format("%s [%d]", name, index),
						cmd = matching_task.cmd,
						path = absolute_path,
						cwd = cwd,
					})
				end
			end
		end

		return definitions
	end,
}
