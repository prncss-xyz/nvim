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
		vim.fn.executable = function(name)
			return (name == "first" or name == "third") and 1 or 0
		end
		local definitions = require("plugins.toggleterm.templates.agents").generator({
			agents = { "first", "missing", "third" },
		})
		assert(#definitions == 2, "expected only installed agents")
		assert(definitions[1].name == "first", "expected first agent")
		assert(definitions[1].builder().priority == 3, "expected first agent to have highest rank")
		assert(definitions[1].tags[1] == "agent", "expected agent tag")
		assert(definitions[2].name == "third", "expected third agent")
		assert(definitions[2].builder().priority == 1, "expected third agent rank")
	]])
end

return T