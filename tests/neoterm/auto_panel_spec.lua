local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
				package.loaded["neoterm.config"] = {
					auto_panel = { width = 40, keybindings = { ["<CR>"] = "open", q = "close" } },
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
		assert(vim.deep_equal(lines(), { "auto mode off", "sample/a  plan:fast  → main", "sample/b  merge  → ambiguous: x-b, y-b" }), vim.inspect(lines()))
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		assert(vim.deep_equal(opened, { "/b/implementation.md" }), vim.inspect(opened))
		upcoming = {}
		tasks_listener()
		assert(vim.deep_equal(lines(), { "auto mode off", "No upcoming auto steps" }), vim.inspect(lines()))
		vim.api.nvim_feedkeys("q", "x", false)
		assert(vim.bo.filetype ~= "toggleterm-auto-panel" and tasks_listener == nil)
	]])
end

return T
