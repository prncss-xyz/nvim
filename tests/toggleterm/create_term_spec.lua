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
		local visible = true
		local terminal = { window = 1 }
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					terminal_options = options
					return terminal
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return visible end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({}, function(event)
			table.insert(events, event)
		end)
		terminal_options.on_exit(terminal, nil, 0)
		visible = false
		terminal_options.on_exit(terminal, nil, 1)
		result = events
	]])

	assert.same({
		{ type = "status", value = "success" },
		{ type = "status", value = "failure" },
	}, child.lua_get("result"))
end

T["create_term"]["reports whether its terminal is in view"] = function()
	child.lua([[local visible = true
		local terminal = { window = 42 }
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function()
					return terminal
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function(winnr) return visible and winnr == terminal.window end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		local instance = Term:new({}, function() end)
		local in_view = instance:is_in_view()
		visible = false
		result = { in_view, instance:is_in_view() }
	]])

	assert.same({ true, false }, child.lua_get("result"))
end

T["create_term"]["passes OSC notifications to the configured notifier"] = function()
	child.lua([[local notification
		local terminal_options
		local terminal = { bufnr = vim.api.nvim_create_buf(false, true) }
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					terminal_options = options
					return terminal
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({}, function() end, false, nil, function(title, message)
			notification = { title, message }
		end)
		vim.wait(10)
		vim.api.nvim_exec_autocmds("TermRequest", {
			buffer = terminal.bufnr,
			data = { sequence = "\27]777;notify;Build;Finished\7" },
		})
		result = notification
	]])

	assert.same({ "Build", "Finished" }, child.lua_get("result"))
end

T["create_term"]["does not steal focus when attaching a created terminal"] = function()
	child.lua([[local ensured = false
		local terminal_buf = vim.api.nvim_create_buf(false, true)
		local file_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(0, file_buf)
		vim.cmd.vsplit()
		local terminal_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(terminal_win, terminal_buf)
		local file_win = vim.fn.win_getid(vim.fn.winnr("h"))
		local terminal = { bufnr = terminal_buf, window = terminal_win }
		package.loaded["toggleterm.terminal"] = {
			Terminal = { new = function() return terminal end },
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return true end,
			is_in_view = function() return true end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = {
			ensure_dir = function()
				vim.api.nvim_set_current_win(file_win)
				ensured = true
			end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		vim.api.nvim_set_current_win(terminal_win)
		require("plugins.toggleterm.terms.create_term"):new({}, function() end)
		vim.wait(100, function() return ensured end)
		result = ensured and vim.api.nvim_get_current_win() == terminal_win
	]])

	assert.same(true, child.lua_get("result"))
end

T["create_term"]["does not let OSC directory updates steal focus"] = function()
	child.lua([[local ensured = false
		local terminal_buf = vim.api.nvim_create_buf(false, true)
		local file_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_win_set_buf(0, file_buf)
		vim.cmd.vsplit()
		local terminal_win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_buf(terminal_win, terminal_buf)
		local file_win = vim.fn.win_getid(vim.fn.winnr("h"))
		local terminal = { bufnr = terminal_buf, window = terminal_win }
		package.loaded["toggleterm.terminal"] = {
			Terminal = { new = function() return terminal end },
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return true end,
			is_in_view = function() return true end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = {
			ensure_dir = function()
				vim.api.nvim_set_current_win(file_win)
				ensured = true
			end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms.create_term"):new({}, function() end)
		vim.wait(10)
		vim.api.nvim_set_current_win(terminal_win)
		vim.api.nvim_exec_autocmds("TermRequest", {
			buffer = terminal.bufnr,
			data = { sequence = "\27]7;file://localhost/tmp\7" },
		})
		vim.wait(100, function() return ensured end)
		result = ensured and vim.api.nvim_get_current_win() == terminal_win
	]])

	assert.same(true, child.lua_get("result"))
end

T["create_term"]["retains OSC title and progress for status detection"] = function()
	child.lua([[local osc
		local scheduled = 0
		local terminal = { bufnr = vim.api.nvim_create_buf(false, true) }
		package.loaded["toggleterm.terminal"] = {
			Terminal = { new = function() return terminal end },
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = {
			attach_term = function(_, _, _, evidence)
				osc = evidence
				return function() end, function()
					scheduled = scheduled + 1
				end
			end,
		}
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms.create_term"):new({}, function() end)
		vim.wait(10)
		vim.api.nvim_exec_autocmds("TermRequest", {
			buffer = terminal.bufnr,
			data = { sequence = "\27]2;◐ Working\7" },
		})
		vim.api.nvim_exec_autocmds("TermRequest", {
			buffer = terminal.bufnr,
			data = { sequence = "\27]9;4;0;0\27\\" },
		})
		vim.api.nvim_exec_autocmds("TermRequest", {
			buffer = terminal.bufnr,
			data = { sequence = "\27]133;D;exit=17\7" },
		})
		result = { osc = osc, scheduled = scheduled }
	]])

	assert.same({
		osc = {
			title = "◐ Working",
			progress = "4;0;0",
			shell_phase = "finished",
			shell_exit_code = "17",
		},
		scheduled = 3,
	}, child.lua_get("result"))
end

T["create_term"]["sends strings as bracketed paste"] = function()
	child.lua([[local sent
		local terminal = { window = 42, job_id = 7 }
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function()
					return terminal
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return true end,
			is_in_view = function() return true end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		vim.api.nvim_chan_send = function(job_id, str)
			sent = { job_id, str }
		end

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({}, function() end):put("@lua/example.lua ")
		vim.wait(100, function() return sent ~= nil end)
		result = sent
	]])

	assert.same({ 7, "\27[200~@lua/example.lua \27[201~" }, child.lua_get("result"))
end

T["create_term"]["ignores process exits while Neovim is shutting down"] = function()
	child.lua([[local terminal_options
		local events = {}
		local spawn_count = 0
		local terminal = { bufnr = 42 }
		function terminal:spawn()
			spawn_count = spawn_count + 1
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
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({ on_exit = "restart" }, function(event)
			table.insert(events, event)
		end, true, 0)
		vim.api.nvim_exec_autocmds("ExitPre", {})
		terminal_options.on_exit(terminal, nil, 1)
		vim.wait(10)
		result = { events = events, spawn_count = spawn_count }
	]])

	assert.same({ events = {}, spawn_count = 1 }, child.lua_get("result"))
end

T["create_term"]["passes only explicitly supported options to toggleterm"] = function()
	child.lua([[local terminal_options
		package.loaded["toggleterm.terminal"] = {
			Terminal = {
				new = function(_, options)
					terminal_options = options
					return {}
				end,
			},
		}
		package.loaded["plugins.toggleterm.terms.attach_term"] = { attach_term = function() end }
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms.create_term"):new({
			cmd = "test-command",
			cwd = "/tmp/test-dir",
			instance_count = 4,
			on_exit = "keep",
			key = "test",
			display_name = "Test",
			priority = 2,
			tag = "test",
		}, function() end)

		result = {
			cmd = terminal_options.cmd,
			dir = terminal_options.dir,
			close_on_exit = terminal_options.close_on_exit,
			env = terminal_options.env,
			has_callbacks = type(terminal_options.on_open) == "function"
				and type(terminal_options.on_create) == "function"
				and type(terminal_options.on_exit) == "function",
			metadata = {
				key = terminal_options.key,
				display_name = terminal_options.display_name,
				instance_count = terminal_options.instance_count,
				priority = terminal_options.priority,
				tag = terminal_options.tag,
			},
		}
	]])

	assert.same({
		cmd = "test-command",
		dir = "/tmp/test-dir",
		close_on_exit = false,
		env = { VMUX_COUNT = 4 },
		has_callbacks = true,
		metadata = {},
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
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({ on_exit = "keep" }, function() end)
		Term:new({ on_exit = "restart" }, function() end)
		Term:new({ on_exit = "close" }, function() end)
		Term:new({}, function() end)
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
		local terminal = { bufnr = vim.api.nvim_create_buf(false, true) }
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
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = {
			ensure_dir = function()
				calls.ensure_dir = calls.ensure_dir + 1
			end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({ on_exit = "restart" }, function(event)
			table.insert(events, event)
		end, true, 0)
		vim.wait(10)
		terminal_options.on_exit(terminal, nil, 1)
		vim.wait(10, function()
			return calls.spawn == 2
		end)
		result = { calls = calls, events = events }
	]])

	assert.same({
		calls = { attach = 1, ensure_dir = 1, open = 0, spawn = 2, toggle = 0 },
		events = { { type = "status", value = "failure" } },
	}, child.lua_get("result"))
end

T["create_term"]["reattaches status detection when toggleterm replaces the buffer"] = function()
	child.lua([[local terminal_options
		local attachments = {}
		local events = {}
		local terminal = {}
		function terminal:spawn()
			self.bufnr = vim.api.nvim_create_buf(false, true)
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
		package.loaded["plugins.toggleterm.terms.attach_term"] = {
			attach_term = function(term, send)
				table.insert(attachments, { bufnr = term.bufnr, send = send })
			end,
		}
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({}, function(event)
			table.insert(events, event)
		end, true)
		vim.wait(20, function() return #attachments == 1 end)
		local first_bufnr = terminal.bufnr
		terminal:spawn()
		vim.wait(20, function() return #attachments == 2 end)
		attachments[1].send({ type = "status", value = "working" })
		attachments[2].send({ type = "status", value = "idle" })
		result = {
			attachment_count = #attachments,
			buffer_replaced = first_bufnr ~= terminal.bufnr,
			events = events,
		}
	]])

	assert.same({
		attachment_count = 2,
		buffer_replaced = true,
		events = {
			{ type = "create" },
			{ type = "status", value = "idle" },
		},
	}, child.lua_get("result"))
end

T["create_term"]["resets status and screen detection when manually restarted"] = function()
	child.lua([[local events = {}
		local reset_count = 0
		local terminal_options
		local terminal = { bufnr = vim.api.nvim_create_buf(false, true), job_id = 7 }
		function terminal:shutdown() end
		function terminal:spawn() end
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
				return function()
					reset_count = reset_count + 1
				end
			end,
		}
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		vim.fn.jobwait = function() return { -1 } end
		vim.fn.jobstop = function() end

		local Term = require("plugins.toggleterm.terms.create_term")
		local instance = Term:new({ screen_manifest = {} }, function(event)
			table.insert(events, event)
		end)
		vim.wait(10)
		instance:restart()
		terminal_options.on_exit(terminal, terminal.job_id, 143)
		vim.wait(10)
		result = { events = events, reset_count = reset_count }
	]])

	assert.same({
		events = { { type = "status", value = "idle" } },
		reset_count = 1,
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
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({ on_exit = "restart" }, function() end, true, 0)
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
		local terminal = { bufnr = vim.api.nvim_create_buf(false, true) }
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
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_visible = function() return false end,
			is_in_view = function() return false end,
		}
		package.loaded["plugins.toggleterm.terms.ensure_dir"] = { ensure_dir = function() end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local Term = require("plugins.toggleterm.terms.create_term")
		Term:new({ on_exit = "restart" }, function() end, true, 100000)
		terminal_options.on_exit(terminal, nil, 0)
		terminal_options.on_exit(terminal, nil, 1)
		vim.wait(10)
		result = spawn_count
	]])

	assert.same(1, child.lua_get("result"))
end

return T
