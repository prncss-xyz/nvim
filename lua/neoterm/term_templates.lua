local M = {}

local function validate_task(task)
	assert(type(task) == "table", "Template task must be a table")
	assert(task.cmd ~= nil or task.agent ~= nil or task.tag == "agent", "Template task must define cmd or agent")

	assert(
		task.cmd == nil or type(task.cmd) == "string" or type(task.cmd) == "function" or vim.islist(task.cmd),
		"Template task cmd must be a string, function, or list"
	)

	return task
end

function M.add_commands(commands, module_names, opts, callback)
	local pending = #module_names
	if pending == 0 then
		return callback(commands)
	end
	local function complete(definitions)
		if type(definitions) == "table" then
			for _, definition in ipairs(definitions) do
				assert(type(definition.name) == "string", "Template definition must have a name")
				commands[definition.name] = validate_task(definition)
			end
		end
		pending = pending - 1
		if pending == 0 then
			callback(commands)
		end
	end
	for _, module_name in ipairs(module_names) do
		local provider = require("neoterm.templates." .. module_name)
		assert(type(provider.generator) == "function", "Template provider must define generator")
		local called = false
		local function done(definitions)
			assert(not called, "Template generator completed twice")
			called = true
			complete(definitions)
		end
		local definitions = provider.generator(opts, done)
		if definitions ~= nil then
			done(definitions)
		end
	end
end

return M
