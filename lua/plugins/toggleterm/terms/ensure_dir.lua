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
	local absolute_dir = vim.fs.normalize(dir)
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" then
			local name = vim.api.nvim_buf_get_name(bufnr)
			if name ~= "" and is_inside_dir(vim.fs.normalize(name), absolute_dir) then
				for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
					if vim.api.nvim_win_get_buf(win) == bufnr then
						vim.api.nvim_set_current_win(win)
						return
					end
				end

				local target_win = get_last_file_win()
				if target_win and vim.api.nvim_win_is_valid(target_win) then
					vim.api.nvim_win_set_buf(target_win, bufnr)
					vim.api.nvim_set_current_win(target_win)
				end
				return
			end
		end
	end

	local path = window.get_path(dir)
	if not path then
		for _, oldfile in ipairs(vim.v.oldfiles) do
			local oldfile_path = vim.fs.normalize(vim.fn.expand(oldfile))
			if is_inside_dir(oldfile_path, absolute_dir) and vim.fn.filereadable(oldfile_path) == 1 then
				path = oldfile_path
				break
			end
		end
	end
	if not path then
		path = dir .. "/README.md"
		if vim.fn.filereadable(path) ~= 1 then
			local ls_output = vim.fn.system({ "git", "-C", dir, "ls-files" })
			if vim.v.shell_error ~= 0 then
				return
			end
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
		if window.create then
			window.create(vim.fn.fnameescape(target_path))
		else
			vim.cmd.edit(vim.fn.fnameescape(target_path))
		end
	end)
end

return M
