local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([=[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. package.path]=])
		end,
		post_once = child.stop,
	},
})

T["matches all literal words case insensitively"] = function()
	child.lua([=[
		local filter = require("neoterm.helpers.filter")
		local rows = { { text = "alpha [beta]" }, { text = "Alpha [beta]" }, { text = "alpha other" } }
		assert(filter.rows(rows, nil) == rows)
		assert(filter.rows(rows, "") == rows)
		assert(#filter.rows(rows, "  ") == 3)
		local result = filter.rows(rows, "[BETA] ALpha")
		assert(#result == 2 and result[1] == rows[1] and result[2] == rows[2])
		assert(#filter.rows(rows, "missing") == 0)
	]=])
end

local function setup()
	child.lua([=[
		filter = require("neoterm.helpers.filter")
		local rows = { { text = "same", id = 1 }, { text = "same", id = 2 }, { text = "other", id = 3 } }
		panel = { win = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf(), rows = rows }
		local ns = vim.api.nvim_create_namespace("filter-test")
		local function render()
			panel.rows = filter.rows(rows, panel.filter)
			vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, vim.tbl_map(function(row) return row.text end, panel.rows))
			vim.api.nvim_buf_clear_namespace(panel.buf, ns, 0, -1)
			filter.highlight(panel, ns)
		end
		render()
		vim.api.nvim_win_set_cursor(panel.win, { 3, 0 })
		filter.open(panel, {
			render = render,
			valid = function() return true end,
			same = function(a, b) return a.id == b.id end,
			accept = function() accepted = panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]].id end,
		})
		input = vim.api.nvim_get_current_buf()
		function press(key)
			for _, map in ipairs(vim.api.nvim_buf_get_keymap(input, "i")) do
				if map.lhs:lower() == key:lower() then map.callback(); return end
			end
			error("Missing mapping " .. key)
		end
		function query(text)
			vim.api.nvim_buf_set_lines(input, 0, -1, false, { text })
			vim.api.nvim_exec_autocmds("TextChangedI", { buffer = input })
		end
	]=])
end

T["debounces, wraps selection, and accepts by identity"] = function()
	setup()
	child.lua([=[
		query("same")
		assert(vim.wait(500, function() return #panel.rows == 2 end))
		press("<C-p>")
		assert(panel.filter_index == 2)
		press("<C-n>")
		assert(panel.filter_index == 1)
		press("<C-n>")
		press("<CR>")
		assert(accepted == 2 and panel.filter == nil and #panel.rows == 3)
		assert(not vim.api.nvim_buf_is_valid(input))
	]=])
end

T["cancel restores cursor and ignores pending updates"] = function()
	setup()
	child.lua([=[
		query("same")
		press("<Esc>")
		vim.wait(150, function() return false end)
		assert(panel.filter == nil and #panel.rows == 3 and accepted == nil)
		assert(vim.api.nvim_win_get_cursor(panel.win)[1] == 3)
	]=])
end

T["accept flushes pending input and handles no matches"] = function()
	setup()
	child.lua([=[
		query("missing")
		press("<CR>")
		assert(accepted == nil and panel.filter == nil and #panel.rows == 3)
	]=])
end

return T
