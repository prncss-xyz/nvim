local M = {}

local opts = {
	buftype = {},
	filetype = { "smear-cursor", "noice" },
}

function M.test_win(win_id)
	local buf_id = vim.api.nvim_win_get_buf(win_id)
	return not (
		vim.tbl_contains(opts.buftype, vim.api.nvim_buf_get_option(buf_id, "buftype"))
		or vim.tbl_contains(opts.filetype, vim.api.nvim_buf_get_option(buf_id, "filetype"))
	)
end

function M.close_all_but_current()
	local current_win_id = vim.api.nvim_get_current_win()
	local windows = vim.api.nvim_tabpage_list_wins(0)
	for _, win_id in ipairs(windows) do
		if win_id ~= current_win_id and M.test_win(win_id) then
			vim.api.nvim_win_close(win_id, false)
		end
	end
end

local history = {}

function M.on_focus()
	local current_win_id = vim.api.nvim_get_current_win()
	if M.test_win(current_win_id) then
		history = vim.tbl_filter(function(v)
			return v ~= current_win_id
		end, history)
		table.insert(history, current_win_id)
	end
end

function M.focus_last()
	history = vim.tbl_filter(function(v)
		return vim.api.nvim_win_is_valid(v)
	end, history)
	if #history > 2 then
		vim.api.nvim_set_current_win(history[#history - 1])
		return
	end
	-- this is useful after splitting
	local windows = vim.api.nvim_tabpage_list_wins(0)
	local current_win_id = vim.api.nvim_get_current_win()
	for _, win_id in ipairs(windows) do
		if win_id ~= current_win_id and M.test_win(win_id) then
			vim.api.nvim_set_current_win(win_id)
			return
		end
	end
end

function M.setup()
	vim.api.nvim_create_autocmd("WinEnter", {
		callback = M.on_focus,
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
			test = M.test_win(win_id),
			current = (win_id == current_win_id) and true or nil,
		})
	end
	dd(infos)
end

return M
