local M = {}

local file_windows = require("neoterm.helpers.file_windows")

local function is_non_floating(win_id)
	return vim.api.nvim_win_is_valid(win_id) and vim.api.nvim_win_get_config(win_id).relative == ""
end

local history = {}

function M.on_win_enter()
	local current_win_id = vim.api.nvim_get_current_win()
	if is_non_floating(current_win_id) then
		local current_tab_id = vim.api.nvim_win_get_tabpage(0)
		history[current_tab_id] = vim.tbl_filter(function(v)
			return v ~= current_win_id
		end, history[current_tab_id] or {})
		table.insert(history[current_tab_id], current_win_id)
	end
end

local function get_last_win()
	local current_win_id = vim.api.nvim_get_current_win()
	local current_tab_id = vim.api.nvim_win_get_tabpage(current_win_id)
	local function cond(win_id)
		return win_id ~= current_win_id and is_non_floating(win_id)
	end
	for i = #history[current_tab_id] - 1, 1, -1 do
		local win_id = history[current_tab_id][i]
		if cond(win_id) then
			return win_id
		end
	end
	-- this is useful after splitting
	local windows = vim.api.nvim_tabpage_list_wins(0)
	for _, win_id in ipairs(windows) do
		if cond(win_id) then
			return win_id
		end
	end
end

function M.focus_last_win()
	local target = get_last_win()
	if target then
		vim.api.nvim_set_current_win(target)
		if vim.bo.buftype == "terminal" then
			vim.cmd.startinsert()
		end
	end
end

function M.get_last_file_win()
	local cur_win = vim.api.nvim_get_current_win()
	if file_windows.can_replace(cur_win) then
		return cur_win
	end

	local wins = history[vim.api.nvim_get_current_tabpage()] or {}
	for i = #wins, 1, -1 do
		if file_windows.can_replace(wins[i]) then
			return wins[i]
		end
	end

	-- Windows created before tracking started may not be in the history.
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if file_windows.can_replace(win) then
			return win
		end
	end
end

return M
