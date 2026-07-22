local M = {}

local nvim_has_focus = true

vim.api.nvim_create_autocmd("FocusGained", {
	callback = function()
		nvim_has_focus = true
	end,
})

vim.api.nvim_create_autocmd("FocusLost", {
	callback = function()
		nvim_has_focus = false
	end,
})

local ctx_by_cwd = {}

local function get_ctx()
	local bufnr = vim.api.nvim_win_get_buf(0)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	local pos = vim.api.nvim_win_get_cursor(0)
	local row = pos[1]
	local col = pos[2]
	return {
		bufnr = bufnr,
		path = path,
		row = row,
		col = col + 1,
	}
end

local function is_text_buffer()
	local bufnr = vim.api.nvim_win_get_buf(0)
	local buf_type = vim.api.nvim_buf_get_option(bufnr, "buftype")
	return buf_type == ""
end

vim.api.nvim_create_autocmd("BufLeave", {
	callback = function()
		if is_text_buffer() then
			ctx_by_cwd[vim.fn.getcwd()] = get_ctx()
		end
	end,
})

function M.get_ctx()
	if is_text_buffer() then
		return get_ctx()
	end
	return ctx_by_cwd[vim.fn.getcwd()]
end

function M.get_path(dir)
	local ctx = ctx_by_cwd[dir]
	if ctx then
		return ctx.path
	end
	return nil
end

function M.is_visible(winnr)
	return winnr and vim.api.nvim_win_is_valid(winnr)
end

function M.is_in_view(winnr)
	return winnr and vim.api.nvim_win_is_valid(winnr) and nvim_has_focus
end

return M
