local M = {}

local window = require("plugins.toggleterm.terms.window")
local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
local find_project_file = require("my.project_file").find
local get_last_file_win = require("my.windows").get_last_file_win

local function find_buffer(path)
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr)) == path then
			return bufnr
		end
	end
end

local function is_in_dir(filename, dir)
	return filename ~= "" and vim.fs.relpath(vim.fs.abspath(dir), vim.fs.abspath(filename)) ~= nil
end

function M.ensure_dir(dir)
	local target_win = get_last_file_win()
	if not target_win or not vim.api.nvim_win_is_valid(target_win) then
		return
	end

	local target_buf = vim.api.nvim_win_get_buf(target_win)
	local target_file = vim.api.nvim_buf_get_name(target_buf)
	if artifact_cwd.contains(target_file) or is_in_dir(target_file, dir) then
		return
	end

	local path = find_project_file(dir)
	if not path then
		return
	end

	local bufnr = find_buffer(path)
	if bufnr then
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if vim.api.nvim_win_get_buf(win) == bufnr then
				vim.api.nvim_set_current_win(win)
				return
			end
		end
	end

	if bufnr then
		vim.api.nvim_win_set_buf(target_win, bufnr)
		vim.api.nvim_set_current_win(target_win)
		return
	end

	vim.api.nvim_win_call(target_win, function()
		if window.create then
			window.create(vim.fn.fnameescape(path))
		else
			vim.cmd.edit(vim.fn.fnameescape(path))
		end
	end)
end

return M
