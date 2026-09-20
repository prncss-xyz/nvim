local M = {}

local visual_types = {
	v = "v",
	V = "V",
	["\22"] = "\22",
	s = "v",
	S = "V",
	["\19"] = "\22",
}

local function selection(path, type_, start, end_, lines)
	return {
		path = path,
		start_row = start[2],
		start_col = start[3],
		end_row = end_[2],
		end_col = end_[3],
		linewise = type_ == "V",
		contents = table.concat(lines, "\n") .. "\n",
	}
end

function M.capture()
	local type_ = visual_types[vim.fn.mode()]
	if not type_ then
		return nil
	end

	local anchor = vim.fn.getpos("v")
	local cursor = vim.fn.getpos(".")
	local start, end_ = anchor, cursor
	if cursor[2] < anchor[2] or (cursor[2] == anchor[2] and cursor[3] < anchor[3]) then
		start, end_ = cursor, anchor
	end

	local lines = vim.fn.getregion(anchor, cursor, { type = type_ })
	local path = require("neoterm.put.path").display(vim.api.nvim_buf_get_name(0))
	return selection(path, type_, start, end_, lines)
end

function M.get(ctx)
	-- exit visual/select mode in the target buffer so marks are set
	if vim.api.nvim_get_current_buf() == ctx.bufnr and vim.fn.mode():match("[vV\22sS\19]") then
		vim.cmd([[noautocmd normal! \<Esc>]])
	end

	local start_mark = vim.api.nvim_buf_get_mark(ctx.bufnr, "<")
	local end_mark = vim.api.nvim_buf_get_mark(ctx.bufnr, ">")
	local type_ = vim.api.nvim_buf_call(ctx.bufnr, vim.fn.visualmode)
	local start_row, start_col = start_mark[1] - 1, start_mark[2]
	local end_row, end_col = end_mark[1] - 1, end_mark[2] + 1
	if type_ == "V" then
		start_col = 0
		end_col = -1
	end

	local lines = vim.api.nvim_buf_get_text(ctx.bufnr, start_row, start_col, end_row, end_col, {})
	local path = require("neoterm.put.path").display(vim.api.nvim_buf_get_name(ctx.bufnr))
	return selection(
		path,
		type_,
		{ 0, start_row + 1, start_col + 1 },
		{ 0, end_row + 1, end_mark[2] + 1 },
		lines
	)
end

function M.span(value, instance)
	local path = require("neoterm.put.path").format(value.path)
	if value.linewise then
		if instance == nil or instance.tag == "agent" then
			return string.format("@%s:L%i-L%i", path, value.start_row, value.end_row)
		end
		return string.format("%s:%i-%i", path, value.start_row, value.end_row)
	end

	if instance == nil or instance.tag == "agent" then
		return string.format(
			"@%s:L%iC:%i-L%iC:%i",
			path,
			value.start_row,
			value.start_col,
			value.end_row,
			value.end_col
		)
	end
	return string.format(
		"%s:%i:%i-%i:%i",
		path,
		value.start_row,
		value.start_col,
		value.end_row,
		value.end_col
	)
end

return M
