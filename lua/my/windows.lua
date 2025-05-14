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


-- taken from mini
--- Zoom in and out of a buffer, making it full screen in a floating window
---
--- This function is useful when working with multiple windows but temporarily
--- needing to zoom into one to see more of the code from that buffer. Call it
--- again (without arguments) to zoom out.
---
---@param buf_id number Buffer identifier (see |bufnr()|) to be zoomed.
---   Default: 0 for current.
---@param config table Optional config for window (as for |nvim_open_win()|).
function M.zoom(buf_id, config)
  if zoom_winid and vim.api.nvim_win_is_valid(zoom_winid) then
    vim.api.nvim_win_close(zoom_winid, true)
    zoom_winid = nil
  else
    buf_id = buf_id or 0
    -- Currently very big `width` and `height` get truncated to maximum allowed
    local default_config = {
      relative = 'editor',
      row = 0,
      col = 0,
      width = 1000,
      height = 1000,
    }
    config = vim.tbl_deep_extend('force', default_config, config or {})
    zoom_winid = vim.api.nvim_open_win(buf_id, true, config)
    vim.cmd 'normal! zz'
  end
end

return M
