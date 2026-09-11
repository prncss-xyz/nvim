local dirs = require("my.parameters").dirs

local function add_definition(definitions, opts)
	table.insert(definitions, {
		name = opts.name,
		builder = function()
			return {
				cmd = string.format(opts.command, opts.path),
				cwd = opts.cwd,
			}
		end,
	})
end

return {
	generator = function(opts)
		local definitions = {}
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
			local command = task and opts.tasks and opts.tasks[task]
			if command then
				local absolute_path = vim.fs.abspath(path)
				local cwd = vim.fs.joinpath(dirs.projects, repo, branch)
				local name = string.format("%s (%s/%s)", task, repo, branch)
				if type(command) == "string" then
					add_definition(definitions, { name = name, command = command, path = absolute_path, cwd = cwd })
				else
					assert(vim.islist(command), string.format("Task %s must be a string or list", task))
					for index, item in ipairs(command) do
						assert(type(item) == "string", string.format("Task %s commands must be strings", task))
						add_definition(definitions, {
							name = string.format("%s [%d]", name, index),
							command = item,
							path = absolute_path,
							cwd = cwd,
						})
					end
				end
			end
		end

		return definitions
	end,
}
