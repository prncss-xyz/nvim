local M = {}

local valid_win = require("my.windows").valid

local history = {}

local function on_focus()
	local current_win_id = vim.api.nvim_get_current_win()
	if valid_win(current_win_id) then
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
		return win_id ~= current_win_id and valid_win(win_id)
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

function M.setup()
	vim.api.nvim_create_autocmd("WinEnter", {
		callback = on_focus,
	})
end

local function is_text_buf(winnr)
	local buf = vim.api.nvim_win_get_buf(winnr)
	local bt = vim.bo[buf].buftype
	return bt == ""
end

function M.get_last_file_win()
	local cur_win = vim.api.nvim_get_current_win()
	if is_text_buf(cur_win) then
		return cur_win
	end

	-- Walk windows in last-accessed order (window doesn't help; use winnr('#') and scan)
	local target_win
	-- First, try the alternate (last visited) window
	local alt_winnr = vim.fn.winnr("#")
	if alt_winnr ~= 0 and alt_winnr ~= vim.fn.winnr() then
		local alt_win = vim.fn.win_getid(alt_winnr)
		if is_text_buf(alt_win) then
			return alt_win
		end
	end

	-- If alternate window isn't a file window, scan all windows for a file buffer (skip current)
	if not target_win then
		for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if w ~= cur_win then
				if is_text_buf(w) then
					return w
				end
			end
		end
	end
end

return M
