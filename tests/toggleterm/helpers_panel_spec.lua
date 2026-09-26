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
		local panel_utils = require("neoterm.helpers.panel")
		local rows = { { text = "alpha [beta]" }, { text = "Alpha [beta]" }, { text = "alpha other" } }
		assert(panel_utils.filter_rows(rows, nil) == rows)
		assert(panel_utils.filter_rows(rows, "") == rows)
		assert(#panel_utils.filter_rows(rows, "  ") == 3)
		local result = panel_utils.filter_rows(rows, "[BETA] ALpha")
		assert(#result == 2 and result[1] == rows[1] and result[2] == rows[2])
		assert(#panel_utils.filter_rows(rows, "missing") == 0)
	]=])
end

local function setup()
	child.lua([=[
		panel_utils = require("neoterm.helpers.panel")
		local rows = { { text = "same", id = 1 }, { text = "same", id = 2 }, { text = "other", id = 3 } }
		panel = { win = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf(), rows = rows }
		local ns = vim.api.nvim_create_namespace("filter-test")
		local function render()
			panel.rows = panel_utils.filter_rows(rows, panel.filter)
			vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, vim.tbl_map(function(row) return row.text end, panel.rows))
			vim.api.nvim_buf_clear_namespace(panel.buf, ns, 0, -1)
			panel_utils.highlight_filter(panel, ns)
		end
		render()
		vim.api.nvim_win_set_cursor(panel.win, { 3, 0 })
		panel_utils.open_filter(panel, {
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

T["binds panel actions and provides help from configured bindings"] = function()
	child.lua([=[
		local utils = require("neoterm.helpers.panel")
		local panel = { buf = vim.api.nvim_get_current_buf() }
		local bindings = { x = "close", ["?"] = "help" }
		local called
		utils.bind(panel, bindings, { close = function(state) called = state end })
		local maps = {}
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(panel.buf, "n")) do
			maps[map.lhs] = map
		end
		assert(maps.x.silent == 1 and maps.x.nowait == 1)
		maps.x.callback()
		assert(called == panel)
		maps["?"].callback()
		local win = vim.api.nvim_get_current_win()
		local buf = vim.api.nvim_get_current_buf()
		assert(buf ~= panel.buf)
		assert(vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), { "?  help", "x  close" }))
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
			if map.lhs == "q" then map.callback(); break end
		end
		assert(not vim.api.nvim_win_is_valid(win))
	]=])
end

T["rejects unknown panel operations"] = function()
	child.lua([=[
		local ok, err = pcall(require("neoterm.helpers.panel").bind,
			{ buf = vim.api.nvim_get_current_buf() }, { x = "missing" }, {})
		assert(not ok and err:find("Unknown panel operation: missing", 1, true))
	]=])
end

return T
