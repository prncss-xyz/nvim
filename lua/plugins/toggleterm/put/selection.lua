local M = {}

local visual_types = {
	v = "v",
	V = "V",
	["\22"] = "\22",
	s = "v",
	S = "V",
	["\19"] = "\22",
}

function M.capture()
	local type_ = visual_types[vim.fn.mode()]
	if not type_ then
		return nil
	end

	local anchor = vim.fn.getpos("v")
	local cursor = vim.fn.getpos(".")
	local start = anchor
	if cursor[2] < anchor[2] or (cursor[2] == anchor[2] and cursor[3] < anchor[3]) then
		start = cursor
	end

	local lines = vim.fn.getregion(anchor, cursor, { type = type_ })
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":.")
	local start_col = type_ == "V" and 1 or start[3]
	local res = { string.format("%s L%iC:%i", path, start[2], start_col) }
	vim.list_extend(res, lines)
	return table.concat(res, "\n") .. "\n"
end

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
	local visual_mode = vim.api.nvim_buf_call(ctx.bufnr, vim.fn.visualmode)
	if visual_mode == "V" then
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
