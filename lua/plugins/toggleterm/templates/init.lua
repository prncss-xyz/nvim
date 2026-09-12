local M = {}

local function shell_join(argv)
	return table.concat(vim.tbl_map(vim.fn.shellescape, argv), " ")
end

local function normalize_task(definition)
	local task = definition.builder({})
	assert(type(task) == "table", "Template builder must return a task")
	assert(task.cmd ~= nil, "Template task must define cmd")

	local cmd = task.cmd
	if type(cmd) == "table" then
		cmd = shell_join(cmd)
	end
	assert(type(cmd) == "string" or type(cmd) == "function", "Template task cmd must be a string, function, or list")

	return {
		cmd = cmd,
		dir = task.cwd or task.dir,
		priority = task.priority,
		tag = definition.tags and definition.tags[1],
		on_exit = "keep",
	}
end

function M.add_commands(commands, module_names, opts)
	for _, module_name in ipairs(module_names) do
		local provider = require("plugins.toggleterm.templates." .. module_name)
		assert(type(provider.generator) == "function", "Template provider must define generator")
		local definitions = provider.generator(opts)
		if type(definitions) == "table" then
			for _, definition in ipairs(definitions) do
				assert(type(definition.name) == "string", "Template definition must have a name")
				assert(type(definition.builder) == "function", "Template definition must have a builder")
				commands[definition.name] = normalize_task(definition)
			end
		end
	end
end

return M
