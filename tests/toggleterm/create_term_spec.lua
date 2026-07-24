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
		create_term({ on_exit = "restart" }, function() end)
		create_term({ on_exit = "close" }, function() end)
		create_term({}, function() end)
		result = vim.tbl_map(function(options)
			return options.close_on_exit
		end, terminal_options)
	]])

	assert.same({ false, false, true, true }, child.lua_get("result"))
end

T["create_term"]["restarts long-running failed processes in the same hidden terminal"] = function()
	child.lua([[local terminal_options
		local calls = { attach = 0, ensure_dir = 0, open = 0, spawn = 0, toggle = 0 }
		local events = {}
		local terminal = { bufnr = 42 }
		function terminal:spawn()
			calls.spawn = calls.spawn + 1
			terminal_options.on_create(self)
		end
		function terminal:open()
			calls.open = calls.open + 1
		end
		function terminal:toggle()
			calls.toggle = calls.toggle + 1
		end
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					terminal_options = options
					return terminal
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = {
			attach_term = function()
				calls.attach = calls.attach + 1
			end,
		}
		package.loaded["plugins.toggleterm.terms.window"] = { is_visible = function() return false end }
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = {
			ensure_dir = function()
				calls.ensure_dir = calls.ensure_dir + 1
			end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local create_term = require("plugins.toggleterm.terms.create_term").create_term
		create_term({ on_exit = "restart" }, function(event)
			table.insert(events, event)
		end, true, 0)
		vim.wait(10)
		terminal_options.on_exit(terminal, nil, 1)
		vim.wait(10, function()
			return calls.spawn == 2
		end)
		result = { calls = calls, events = events, bufnr = terminal.bufnr }
	]])

	assert.same({
		calls = { attach = 1, ensure_dir = 1, open = 0, spawn = 2, toggle = 0 },
		events = { { type = "status", value = "failure" } },
		bufnr = 42,
	}, child.lua_get("result"))
end

T["create_term"]["reuses a terminal buffer containing output"] = function()
	child.lua([[local terminal_options
		local spawn_count = 0
		local spawn_errors = {}
		local terminal = { bufnr = vim.api.nvim_create_buf(true, false) }
		function terminal:spawn()
			spawn_count = spawn_count + 1
			local ok, error = pcall(vim.api.nvim_buf_call, self.bufnr, function()
				self.job_id = vim.fn.termopen({ "sh", "-c", "printf output" })
			end)
			if not ok then
				table.insert(spawn_errors, error)
				return
			end
			terminal_options.on_create(self)
		end
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					terminal_options = options
					return terminal
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = { is_visible = function() return false end }
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local create_term = require("plugins.toggleterm.terms.create_term").create_term
		create_term({ on_exit = "restart" }, function() end, true, 0)
		vim.fn.jobwait({ terminal.job_id }, 1000)
		terminal_options.on_exit(terminal, nil, 1)
		vim.wait(100, function()
			return spawn_count == 2
		end)
		result = { spawn_count = spawn_count, spawn_errors = spawn_errors }
	]])

	assert.same({ spawn_count = 2, spawn_errors = {} }, child.lua_get("result"))
end

T["create_term"]["does not restart successful or short-lived processes"] = function()
	child.lua([[local terminal_options
		local spawn_count = 0
		local terminal = { bufnr = 42 }
		function terminal:spawn()
			spawn_count = spawn_count + 1
			terminal_options.on_create(self)
		end
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					terminal_options = options
					return terminal
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = { is_visible = function() return false end }
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local create_term = require("plugins.toggleterm.terms.create_term").create_term
		create_term({ on_exit = "restart" }, function() end, true, 100000)
		terminal_options.on_exit(terminal, nil, 0)
		terminal_options.on_exit(terminal, nil, 1)
		vim.wait(10)
		result = spawn_count
	]])

	assert.same(1, child.lua_get("result"))
end

return T
