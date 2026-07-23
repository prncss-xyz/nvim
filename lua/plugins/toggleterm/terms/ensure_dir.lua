local M = {}

local window = require("plugins.toggleterm.terms.window")
local get_last_file_win = require("my.windows").get_last_file_win

local function get_absolute_path(path, dir)
	if vim.fn.isabsolutepath(path) == 1 then
		return vim.fs.normalize(path)
	end
	return vim.fs.normalize(vim.fs.joinpath(dir, path))
end

local function is_inside_dir(path, dir)
	local relative = vim.fs.relpath(dir, path)
	return relative ~= nil and relative ~= "." and not relative:match("^%.%.[/\\\\]")
end

function M.ensure_dir(dir)
	local cwd = vim.fn.getcwd()
	local absolute_dir = get_absolute_path(dir, cwd)
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local bufnr = vim.api.nvim_win_get_buf(win)
		if vim.bo[bufnr].buftype == "" then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" and is_inside_dir(get_absolute_path(name, cwd), absolute_dir) then
				return
			end
		end
	end

	local path = window.get_path(dir)
	if not dir then
		path = dir .. "/README.md"
		if vim.fn.filereadable(path) ~= 1 then
			local ls_output = vim.fn.system({ "git", "-C", dir, "ls-files" })
			local first = ls_output:match("[^\n]+")
			if first then
				path = dir .. "/" .. first
			else
				path = dir .. "/README.md"
			end
		end
	end

	if not path or path == "" then
		return
	end

	local target_win = get_last_file_win()
	if not target_win or not vim.api.nvim_win_is_valid(target_win) then
		return
	end

	local target_path = get_absolute_path(path, absolute_dir)
	vim.api.nvim_win_call(target_win, function()
		require("khutulun").create(vim.fn.fnameescape(target_path))
	end)
end

return M
