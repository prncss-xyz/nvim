local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
				package.loaded["neoterm.config"] = {
					auto_panel = { width = 40, keybindings = { ["<CR>"] = "open", q = "close", ["/"] = "filter" } },
					filter = { keybindings = { ["<C-n>"] = "next", ["<CR>"] = "accept" } },
				}
				package.loaded["neoterm.terms.artifacts.tasks"] = {
					subscribe = function(listener)
						tasks_listener = listener
						return function()
							tasks_listener = nil
						end
					end,
				}
				upcoming = {}
				package.loaded["neoterm.terms.artifacts.auto"] = {
					upcoming = function()
						return upcoming
					end,
					auto_status = function() end,
					subscribe_auto = function()
						return function() end
					end,
				}
				opened = {}
				package.loaded["neoterm.helpers.file_windows"] = {
					open = function(path)
						table.insert(opened, path)
					end,
				}
				function lines()
					return vim.api.nvim_buf_get_lines(0, 0, -1, false)
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["lists upcoming auto steps in order and opens the step file"] = function()
	child.lua([[
		upcoming = {
			{ task = { parts = { "sample", "a" } }, step = { name = "plan" }, variant = "fast", file = "/a/task.md", checkouts = {}, cwd = "/p/main" },
			{ task = { parts = { "sample", "b" } }, step = { name = "merge" }, file = "/b/implementation.md", checkouts = { "/p/x-b", "/p/y-b" } },
		}
		require("neoterm.auto_panel").toggle()
		assert(vim.deep_equal(lines(), { "auto mode off", "sample/", "  a  plan:fast  → main", "  b  merge  → ambiguous: x-b, y-b", "count: 2" }), vim.inspect(lines()))
		assert(vim.api.nvim_win_get_cursor(0)[1] == 3)
		vim.api.nvim_win_set_cursor(0, { 4, 0 })
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		assert(vim.deep_equal(opened, { "/b/implementation.md" }), vim.inspect(opened))
		upcoming = {}
		tasks_listener()
		assert(vim.deep_equal(lines(), { "auto mode off", "No upcoming auto steps", "count: 0" }), vim.inspect(lines()))
		vim.api.nvim_feedkeys("q", "x", false)
		assert(vim.bo.filetype ~= "toggleterm-auto-panel" and tasks_listener == nil)
	]])
end

T["groups nested directories without changing task order"] = function()
	child.lua([[
		upcoming = {}
		for _, parts in ipairs({
			{ "alpha", "nested", "a" },
			{ "alpha", "nested", "b" },
			{ "alpha", "nested" },
			{ "alpha", "other", "a" },
			{ "beta", "nested", "a" },
			{ "standalone" },
		}) do
			table.insert(upcoming, { task = { parts = parts }, step = { name = "plan" }, file = "/" .. table.concat(parts, "/") .. "/task.md", cwd = "/p/main" })
		end
		require("neoterm.terms.artifacts.auto").auto_status = function() return "waiting for task alpha/nested/a" end
		require("neoterm.auto_panel").toggle()
		assert(vim.deep_equal(lines(), {
			"waiting for task alpha/nested/a",
			"alpha/",
			"  nested/",
			"    a  plan  → main",
			"    b  plan  → main",
			"  nested  plan  → main",
			"  other/",
			"    a  plan  → main",
			"beta/",
			"  nested/",
			"    a  plan  → main",
			"standalone  plan  → main",
			"count: 6",
		}), vim.inspect(lines()))
		local namespace = vim.api.nvim_get_namespaces()["toggleterm-auto-panel"]
		local last = #lines() - 1
		local marks = vim.api.nvim_buf_get_extmarks(0, namespace, { last, 0 }, { last, -1 }, { details = true })
		assert(marks[1][4].hl_group == "Comment", vim.inspect(marks))
	]])
end

T["filters full paths and opens matching tasks with duplicate leaf names"] = function()
	child.lua([[
		upcoming = {}
		for _, parts in ipairs({ { "alpha", "a" }, { "beta", "a" }, { "beta", "b" } }) do
			table.insert(upcoming, { task = { parts = parts }, step = { name = "plan" }, file = "/" .. table.concat(parts, "/") .. "/task.md", cwd = "/p/main" })
		end
		require("neoterm.auto_panel").toggle()
		local panel_buf = vim.api.nvim_get_current_buf()
		assert(vim.fn.maparg("/", "n", false, true).callback)()
		local input = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_lines(input, 0, -1, false, { "beta/a" })
		vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input })
		assert(vim.wait(500, function()
			return vim.api.nvim_buf_get_lines(panel_buf, -2, -1, false)[1] == "count: 1"
		end))
		assert(vim.deep_equal(vim.api.nvim_buf_get_lines(panel_buf, 0, -1, false), {
			"auto mode off", "beta/", "  a  plan  → main", "count: 1",
		}))
		assert(vim.fn.maparg("<C-n>", "i", false, true).callback)()
		assert(vim.fn.maparg("<C-n>", "i", false, true).callback)()
		assert(vim.fn.maparg("<CR>", "i", false, true).callback)()
		assert(vim.deep_equal(opened, { "/beta/a/task.md" }), vim.inspect(opened))
		assert(lines()[#lines()] == "count: 3")
	]])
end

return T
