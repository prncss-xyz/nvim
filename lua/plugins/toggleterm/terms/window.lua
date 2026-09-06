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

local function path_through_cwd_symlink(bufnr, path)
	local cwd = vim.b[bufnr].my_rooter_symlink_cwd
	if cwd == nil or path:sub(1, 1) ~= "/" then
		return nil
	end

	local matches = vim.fs.find(function(name, parent)
		local link = vim.fs.joinpath(parent, name)
		local metadata = vim.uv.fs_lstat(link)
		if not metadata or metadata.type ~= "link" then
			return false
		end

		local target = vim.uv.fs_realpath(link)
		return target ~= nil and (path == target or path:sub(1, #target + 1) == target .. "/")
	end, { path = cwd, limit = 1 })
	local link = matches[1]
	if not link then
		return nil
	end

	local target = vim.uv.fs_realpath(link)
	return link .. path:sub(#target + 1)
end

local function get_ctx()
	local bufnr = vim.api.nvim_win_get_buf(0)
	local name = vim.api.nvim_buf_get_name(bufnr)
	local path = vim.fn.fnamemodify(path_through_cwd_symlink(bufnr, name) or name, ":.")
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

---@param path string
function M.create(path)
	require("my.create").create(path)
end

function M.is_visible(winnr)
	return winnr and vim.api.nvim_win_is_valid(winnr)
end

function M.is_in_view(winnr)
	return winnr and vim.api.nvim_win_is_valid(winnr) and nvim_has_focus
end

return M
