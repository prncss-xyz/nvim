local M = {}

function M.blank_line(fwd)
	local replacement = {}
	for _ = 1, vim.v.count1 do
		table.insert(replacement, "")
	end
	local pos = vim.api.nvim_win_get_cursor(0)
	local row = pos[1] - 1 + (fwd and 1 or 0)
	vim.api.nvim_buf_set_lines(0, row, row, true, replacement)
end

return M
