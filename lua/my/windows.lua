local M = {}

function M.close_all_but_current()
	local current_win_id = vim.api.nvim_get_current_win()
	local windows = vim.api.nvim_tabpage_list_wins(0)
	for _, win_id in ipairs(windows) do
		if win_id ~= current_win_id then
			vim.api.nvim_win_close(win_id, false)
		end
	end
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
			current = (win_id == current_win_id) and true or nil,
		})
	end
	dd(infos)
end

return M
