local M = {}

function M.show(bindings)
	local keys = vim.tbl_keys(bindings)
	table.sort(keys)
	local width = 0
	for _, key in ipairs(keys) do
		width = math.max(width, vim.fn.strdisplaywidth(key))
	end
	local lines = {}
	for _, key in ipairs(keys) do
		table.insert(lines, key .. string.rep(" ", width - vim.fn.strdisplaywidth(key) + 2) .. bindings[key])
	end
	local content_width = 0
	for _, line in ipairs(lines) do
		content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - #lines) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - content_width) / 2)),
		width = content_width,
		height = #lines,
		style = "minimal",
		border = "single",
	})
	for _, key in ipairs({ "q", "<Esc>", "h" }) do
		vim.keymap.set("n", key, function()
			vim.api.nvim_win_close(win, true)
		end, { buffer = buf, silent = true, nowait = true })
	end
end

return M
