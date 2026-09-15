local M = {}

local function normalize_task(definition)
	local task = definition.builder({})
	assert(type(task) == "table", "Template builder must return a task")
	assert(task.cmd ~= nil, "Template task must define cmd")

	assert(
		type(task.cmd) == "string" or type(task.cmd) == "function" or vim.islist(task.cmd),
		"Template task cmd must be a string, function, or list"
	)

	return {
		cmd = task.cmd,
		cwd = task.cwd,
		priority = task.priority,
		auto_scroll = task.auto_scroll,
		tag = definition.tag,
		on_exit = task.on_exit,
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
