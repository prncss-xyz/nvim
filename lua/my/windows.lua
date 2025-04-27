local M = {}

function M.close_all_but_current()
	local current_win_id = vim.api.nvim_get_current_win()
	local windows = vim.api.nvim_tabpage_list_wins(0) -- 0 for current tabpage
	for _, win_id in ipairs(windows) do
		if win_id ~= current_win_id then
			vim.api.nvim_win_close(win_id, false)
		end
	end
end

return M
