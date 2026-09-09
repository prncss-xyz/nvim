local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua(
				[[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path]]
			)
		end,
		post_once = child.stop,
	},
})

T["selection templates capture the active selection before expansion"] = function()
	child.lua([[
		vim.api.nvim_buf_set_name(0, "selection.lua")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = 1", "return value" })
		vim.api.nvim_win_set_cursor(0, { 1, 6 })
		vim.cmd("normal! v4l")

		local put = require("plugins.toggleterm.put.core")
		local invocation = put.capture("explain {selection}")

		vim.cmd("normal! \\<Esc>")
		vim.api.nvim_buf_set_lines(0, 0, 1, false, { "local other = 2" })

		local ctx = require("plugins.toggleterm.terms.window").get_ctx(invocation)
		local result = put.template("explain {selection}")(ctx, {})
		assert(result == "explain selection.lua L1C:7\nvalue\n", result)
	]])
end

T["selection templates use the last selection after focusing a terminal"] = function()
	child.lua([[
		local window = require("plugins.toggleterm.terms.window")
		vim.api.nvim_buf_set_name(0, "selection.lua")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local value = 1", "return value" })
		vim.api.nvim_win_set_cursor(0, { 1, 6 })
		vim.cmd("normal! v4l")
		vim.cmd("normal! \\<Esc>")

		vim.cmd.terminal()

		local put = require("plugins.toggleterm.put.core")
		local invocation = put.capture("explain {selection}")
		local ctx = window.get_ctx(invocation)
		local result = put.template("explain {selection}")(ctx, {})
		assert(result == "explain selection.lua L1C:7\nvalue\n", result)
	]])
end

T["selection capture preserves linewise regions"] = function()
	child.lua([[
		vim.api.nvim_buf_set_name(0, "selection.lua")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second", "third" })
		vim.api.nvim_win_set_cursor(0, { 1, 2 })
		vim.cmd("normal! Vj")

		local selection = require("plugins.toggleterm.put.selection").capture()
		assert(selection == "selection.lua L1C:1\nfirst\nsecond\n", selection)
	]])
end

return T
