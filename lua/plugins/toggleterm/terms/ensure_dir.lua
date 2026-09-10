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

function M.open_dir(dir, target_win, use_visible_window, exclude)
	local path = find_project_file(dir, exclude)
	if not path then
		return
	end

	local bufnr = find_buffer(path)
	if bufnr and use_visible_window then
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
		if use_visible_window and window.create then
			window.create(vim.fn.fnameescape(path))
		else
			vim.cmd.edit(vim.fn.fnameescape(path))
		end
	end)
end

local function ensure_dir(dir, exclude)
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local path = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
		local is_excluded = exclude and vim.iter(exclude):any(function(excluded)
			return is_in_dir(path, excluded)
		end)
		if is_in_dir(path, dir) and not is_excluded then
			vim.api.nvim_set_current_win(win)
			return
		end
	end

	local target_win = get_last_file_win()
	if not target_win or not vim.api.nvim_win_is_valid(target_win) then
		return
	end

	local target_buf = vim.api.nvim_win_get_buf(target_win)
	local target_file = vim.api.nvim_buf_get_name(target_buf)
	local is_excluded = exclude and vim.iter(exclude):any(function(path)
		return is_in_dir(target_file, path)
	end)
	if (artifact_cwd.contains(target_file) or is_in_dir(target_file, dir)) and not is_excluded then
		return
	end

	M.open_dir(dir, target_win, true, exclude)
end

function M.ensure_dir(dir)
	ensure_dir(dir)
end

function M.ensure_dir_excluding(dir, exclude)
	ensure_dir(dir, exclude)
end

return M
