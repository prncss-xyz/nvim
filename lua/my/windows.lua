local M = {}

local opts = {
	buftype = {},
	filetype = { "smear-cursor", "noice" },
}

local function valid_win(win_id)
	if not vim.api.nvim_win_is_valid(win_id) then
		return false
	end
	local buf_id = vim.api.nvim_win_get_buf(win_id)
	local buf_type = vim.api.nvim_buf_get_option(buf_id, "buftype")
	return not (vim.tbl_contains(opts.buftype, buf_type) or vim.tbl_contains(opts.filetype, buf_type))
end

local history = {}

local function on_focus()
	local current_win_id = vim.api.nvim_get_current_win()
	if valid_win(current_win_id) then
		history = vim.tbl_filter(function(v)
			return v ~= current_win_id
		end, history)
		table.insert(history, current_win_id)
	end
end

local function is_win_file(win_id)
	local buf_id = vim.api.nvim_win_get_buf(win_id)
	local buf_type = vim.api.nvim_buf_get_option(buf_id, "buftype")
	return buf_type == ""
end

function M.close_all_but_current()
	local current_win_id = vim.api.nvim_get_current_win()
	local windows = vim.api.nvim_tabpage_list_wins(0)
	for _, win_id in ipairs(windows) do
		if win_id ~= current_win_id and valid_win(win_id) then
			vim.api.nvim_win_close(win_id, false)
		end
	end
end

function M.is_file_cur_win()
	local winid = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_win_get_buf(winid)
	local buf_type = vim.api.nvim_buf_get_option(bufnr, "buftype")
	return buf_type == ""
end

local function focus_last_win2(cb, ...)
	if not cb then
		return
	end
	local current_win_id = vim.api.nvim_get_current_win()
	local function cond(win_id)
		return win_id ~= current_win_id and valid_win(win_id) and cb(win_id)
	end
	for i = #history - 1, 1, -1 do
		local win_id = history[i]
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
	if last then
		return
	end
	return focus_last_win(...)
end

function M.get_last_n(n, win_id)
	local res = {}
	for i = #history - 1, 1, -1 do
		local h_win_id = history[i]
		if is_win_file(h_win_id) then
			if win_id == h_win_id then
				table.insert(res, h_win_id)
				if #res == n then
					break
				end
			end
		end
	end
	return res
end

local function focus_last_win(file, last)
	local current_win_id = vim.api.nvim_get_current_win()
	local function cond(win_id)
		return win_id ~= current_win_id and valid_win(win_id) and is_win_file(win_id) == file
	end
	for i = #history - 1, 1, -1 do
		local win_id = history[i]
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
	if last then
		return
	end
	return focus_last_win(not file, true)
end

function M.focus_last_win(file)
	local target = focus_last_win(file)
	if target then
		vim.api.nvim_set_current_win(target)
	end
end

function M.setup()
	vim.api.nvim_create_autocmd("WinEnter", {
		callback = on_focus,
	})
end

function M.list()
	local current_win_id = vim.api.nvim_get_current_win()
	local windows = vim.api.nvim_tabpage_list_wins(0)
	local infos = {}
	for _, win_id in ipairs(windows) do
		local buf_id = vim.api.nvim_win_get_buf(win_id)
		table.insert(infos, {
			filetype = vim.api.nvim_buf_get_option(buf_id, "filetype"),
			buftype = vim.api.nvim_buf_get_option(buf_id, "buftype"),
			test = valid_win(win_id),
			current = (win_id == current_win_id) and true or nil,
		})
	end
end

function M.swap(winid)
	if not winid then
		return
	end
	local cur_winid = vim.api.nvim_get_current_win()
	local cur_bufnr = vim.api.nvim_win_get_buf(cur_winid)
	local target_bufnr = vim.api.nvim_win_get_buf(winid)
	if cur_bufnr == target_bufnr then
		local cur_pos = vim.api.nvim_win_get_cursor(cur_winid)
		local target_pos = vim.api.nvim_win_get_cursor(winid)
		vim.api.nvim_win_set_cursor(cur_winid, target_pos)
		vim.api.nvim_win_set_cursor(winid, cur_pos)
		return
	end
	vim.api.nvim_win_set_buf(cur_winid, target_bufnr)
	vim.api.nvim_win_set_buf(winid, cur_bufnr)
end

return M
