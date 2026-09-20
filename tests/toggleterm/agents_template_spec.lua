local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["agents template adds installed agents ranked by list order"] = function()
	child.lua([[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["neoterm.templates.async"] = {
			executable = function(name, callback)
				vim.schedule(function() callback(name == "first" or name == "third") end)
			end,
		}
		local definitions
		require("neoterm.templates.agents").generator({
			agents = { "first", "missing", "third" },
		}, function(result) definitions = result end)
		vim.wait(1000, function() return definitions ~= nil end)
		assert(#definitions == 2, "expected only installed agents")
		assert(definitions[1].name == "first", "expected first agent")
		assert(definitions[1].builder().priority == 3, "expected first agent to have highest rank")
		assert(definitions[1].builder().tag == "agent", "expected agent tag")
		assert(definitions[2].name == "third", "expected third agent")
		assert(definitions[2].builder().priority == 1, "expected third agent rank")
	]])
end

T["templates add asynchronous agent definitions"] = function()
	child.lua([[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["neoterm.templates.async"] = {
			executable = function(_, callback) vim.schedule(function() callback(true) end) end,
		}
		local commands
		require("neoterm.term_templates").add_commands({}, { "agents" }, {
			agents = { "p" },
		}, function(result) commands = result end)
		vim.wait(1000, function() return commands ~= nil end)
		assert(commands.p.tag == "agent", "expected task tag to be preserved")
	]])
end

return T
