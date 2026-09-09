local M = {}

function M.get_selection(ctx)
	-- exit visual/select mode in the target buffer so marks are set
	if vim.api.nvim_get_current_buf() == ctx.bufnr and vim.fn.mode():match("[vV\22sS\19]") then
		vim.cmd([[noautocmd normal! \<Esc>]])
	end

	local start = vim.api.nvim_buf_get_mark(ctx.bufnr, "<")
	local end_ = vim.api.nvim_buf_get_mark(ctx.bufnr, ">")
	local start_row, start_col = start[1] - 1, start[2]
	local end_row, end_col = end_[1] - 1, end_[2] + 1

	-- for linewise visual mode, extend end_col to line end
	if vim.fn.visualmode() == "V" then
		end_col = -1
	end

	local lines = vim.api.nvim_buf_get_text(ctx.bufnr, start_row, start_col, end_row, end_col, {})
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(ctx.bufnr), ":.")

	local res = { string.format("%s L%iC:%i", path, start_row + 1, start_col + 1) }
	vim.list_extend(res, lines)
	-- concatenate lines adding a line break at the end of each
	return table.concat(res, "\n") .. "\n"
end

return M
