local artifact_commands = require("plugins.toggleterm.artifact_commands")
local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")

local function script_definitions(opts, callback)
	local cwd = opts.cwd or opts.dir or vim.fn.getcwd()
	local file = opts.file and vim.fs.abspath(opts.file) or nil
	local dir
	if file and artifact_cwd.contains(file) then
		dir = vim.fs.dirname(file)
	elseif artifact_cwd.contains(cwd) then
		dir = vim.fs.abspath(cwd)
	else
		dir = artifact_cwd.for_checkout(cwd)
	end
	if not dir then
		return callback({})
	end
	local definitions = {}
	for _, path in ipairs(require("plugins.toggleterm.artifact_tasks").executables(dir)) do
		local relative = assert(vim.fs.relpath(dir, path))
		table.insert(definitions, {
			name = "artifact " .. relative,
			builder = function()
				return { cmd = { path }, cwd = cwd, exit_policy = "keep" }
			end,
		})
	end
	callback(definitions)
end

return {
	generator = function(opts, callback)
		local definitions = {}
		local pending = 2
		local function complete(generated)
			vim.list_extend(definitions, generated)
			pending = pending - 1
			if pending == 0 then
				table.sort(definitions, function(a, b)
					return a.name < b.name
				end)
				callback(definitions)
			end
		end

		artifact_commands.generator(opts, complete)
		script_definitions(opts, complete)
	end,
}
