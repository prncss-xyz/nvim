local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["screen status events"] = MiniTest.new_set()

T["screen status events"]["marks unseen changes as seen when focus is regained in view"] = function()
	child.lua([[local notifications = {}
		local send
		local term_window = vim.api.nvim_open_win(
			vim.api.nvim_create_buf(false, true),
			true,
			{ width = 10, height = 5, relative = "editor", row = 0, col = 0 }
		)
		local item = {
			key = "agent",
			display_name = "agent",
			dir = "/tmp",
		}

		package.loaded["neoterm.terms.create_term"] = {
			new = function(_, _, handler)
				send = handler
				return {
					focus = function() end,
					is_in_view = function()
						return require("neoterm.terms.window").is_in_view(term_window)
					end,
				}
			end,
		}
		package.loaded["neoterm.config"] = {
			on_status = function(instance)
				table.insert(notifications, instance.status)
			end,
			middlewares = {},
		}
		package.loaded["neoterm.terms.get_query_fn"] = {
			get_query_fn = function() return function() return true end end,
		}
		package.loaded["neoterm.terms.get_commands"] = {
			get_commands = function(_, _, callback) callback({ item }) end,
		}
		package.loaded["neoterm.terms.artifacts.cwd"] = {
			context_dir = function() return nil end,
		}
		package.loaded["neoterm.put.path"] = {
			display = function(path) return path end,
		}
		package.loaded["neoterm.git"] = {
			ensure_worktree = function(_, callback) callback(true) end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local terms = require("neoterm.terms")
		terms.focus({})

		-- a status change that arrives while neovim lacks focus is unseen,
		-- even though the terminal window stays displayed
		vim.api.nvim_exec_autocmds("FocusLost", {})
		send({ type = "status", value = "success", visible = false })
		local unseen = item.changed
		local changed_terminals = terms.has_changed()

		-- regaining focus with the terminal in view marks the change as seen
		vim.api.nvim_exec_autocmds("FocusGained", {})
		local seen_after_regain = item.changed
		local has_changed_after_regain = terms.has_changed()

		-- a change that arrives while the terminal window is closed stays unseen on focus regained
		vim.api.nvim_exec_autocmds("FocusLost", {})
		send({ type = "status", value = "failure", visible = false })
		vim.api.nvim_win_close(term_window, false)
		vim.api.nvim_exec_autocmds("FocusGained", {})
		local still_changed = item.changed

		-- once the terminal window is displayed again, the next focus regain marks it seen
		term_window = vim.api.nvim_open_win(
			vim.api.nvim_create_buf(false, true),
			true,
			{ width = 10, height = 5, relative = "editor", row = 0, col = 0 }
		)
		vim.api.nvim_exec_autocmds("FocusGained", {})

		result = {
			unseen = unseen,
			changed_terminals = changed_terminals,
			seen_after_regain = seen_after_regain,
			has_changed_after_regain = has_changed_after_regain,
			still_changed = still_changed,
			resolved = item.changed,
			notifications = notifications,
		}
	]])

	assert.same({
		unseen = true,
		changed_terminals = true,
		seen_after_regain = nil,
		has_changed_after_regain = false,
		still_changed = true,
		resolved = nil,
		notifications = { "success", "failure" },
	}, child.lua_get("result"))
end

T["directory queries"] = MiniTest.new_set()

T["directory queries"]["matches HOME exactly"] = function()
	local get_query_fn = require("neoterm.terms.get_query_fn").get_query_fn
	local filter = get_query_fn({ dir = vim.env.HOME })

	assert(filter({ dir = vim.env.HOME }))
	assert(not filter({ dir = vim.fs.joinpath(vim.env.HOME, "unrelated") }))
end

return T
