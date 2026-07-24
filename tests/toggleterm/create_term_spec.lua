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

T["create_term"]["reports process exit status"] = function()
	child.lua([[local terminal_options
		local events = {}
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					terminal_options = options
					return {}
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = { is_visible = function() return false end }
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local create_term = require("plugins.toggleterm.terms.create_term").create_term
		create_term({}, function(event)
			table.insert(events, event)
		end)
		terminal_options.on_exit(nil, nil, 0)
		terminal_options.on_exit(nil, nil, 1)
		result = events
	]])

	assert.same({
		{ type = "status", value = "success" },
		{ type = "status", value = "failure" },
	}, child.lua_get("result"))
end

T["create_term"]["maps on_exit to toggleterm's close_on_exit option"] = function()
	child.lua([[local terminal_options = {}
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					table.insert(terminal_options, options)
					return {}
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = { is_visible = function() return false end }
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local create_term = require("plugins.toggleterm.terms.create_term").create_term
		create_term({ on_exit = "keep" }, function() end)
		create_term({ on_exit = "close" }, function() end)
		create_term({}, function() end)
		result = vim.tbl_map(function(options)
			return options.close_on_exit
		end, terminal_options)
	]])

	assert.same({ false, true, true }, child.lua_get("result"))
end

return T
