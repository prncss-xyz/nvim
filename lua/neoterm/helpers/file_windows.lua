local M = {}

M.open_files_do_not_replace_types = require("neoterm.config").open_files_do_not_replace_types

function M.can_focus(win)
	if
		not vim.api.nvim_win_is_valid(win)
		or vim.api.nvim_win_get_tabpage(win) ~= vim.api.nvim_get_current_tabpage()
	then
		return false
	end
	local config = vim.api.nvim_win_get_config(win)
	if config.relative ~= "" or config.external then
		return false
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local ft = vim.bo[buf].filetype
	return vim.bo[buf].buftype == "" and ft ~= "neo-tree" and not vim.tbl_contains(M.open_files_do_not_replace_types, ft)
end

function M.can_replace(win)
	return M.can_focus(win) and not vim.wo[win].winfixbuf
end

function M.open(path, bufnr)
	local win = require("neoterm.helpers.win_history").get_last_file_win()
	if not win then
		return false
	end
	if bufnr then
		vim.api.nvim_win_set_buf(win, bufnr)
	else
		vim.api.nvim_win_call(win, function()
			require("neoterm.config").create(vim.fn.fnameescape(path))
		end)
	end
	vim.api.nvim_set_current_win(win)
	return true
end

return M
