local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["create_term"] = MiniTest.new_set()

T["create_term"]["spawns prepared terminals without opening a window"] = function()
	child.lua([[local spawned = false
		local terminal_options
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					terminal_options = options
					return {
						options = options,
						spawn = function()
							spawned = true
						end,
					}
				end,
			},
		}
		package.loaded["plugins.toggleterm.idle"] = { start_idle_detection = function() end }
		package.loaded["plugins.toggleterm.window"] = { is_visible = function() return false end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local create_term = require("plugins.toggleterm.create_term").create_term
		local term = create_term({ key = "ddgr" }, function() end, true)
		result = { spawned = spawned, hidden = terminal_options.hidden, returned = term ~= nil }
	]])

	assert.same({ spawned = true, hidden = true, returned = true }, child.lua_get("result"))
end

return T
