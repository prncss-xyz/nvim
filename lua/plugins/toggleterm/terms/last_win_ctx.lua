local M = {}

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

function M.get_ctx()
	local winnr = M.get_last_file_win()
	if not winnr then
		return
	end
	local bufnr = vim.api.nvim_win_get_buf(winnr)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	local pos = vim.api.nvim_win_get_cursor(winnr)
	local row = pos[1]
	local col = pos[2]
	return {
		bufnr = bufnr,
		path = path,
		row = row,
		col = col + 1,
		winnr = winnr,
	}
end

return M
