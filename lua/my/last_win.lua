local M = {}

function M.get_last_file_win()
	local cur_win = vim.api.nvim_get_current_win()
	-- Walk windows in last-accessed order (window doesn't help; use winnr('#') and scan)
	local target_win
	-- First, try the alternate (last visited) window
	local alt_winnr = vim.fn.winnr("#")
	if alt_winnr ~= 0 and alt_winnr ~= vim.fn.winnr() then
		local alt_win = vim.fn.win_getid(alt_winnr)
		local buf = vim.api.nvim_win_get_buf(alt_win)
		local bt = vim.bo[buf].buftype
		if bt == "" then
			target_win = alt_win
		end
	end
	-- If alternate window isn't a file window, scan all windows for a file buffer (skip current)
	if not target_win then
		for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			if w ~= cur_win then
				local buf = vim.api.nvim_win_get_buf(w)
				if vim.bo[buf].buftype == "" then
					target_win = w
					break
				end
			end
		end
	end
	return target_win
end

function M.put_with_last(cb)
	local last_win = M.get_last_file_win()
	if last_win then
		local buf = vim.api.nvim_win_get_buf(last_win)
		local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":.")
		local pos = vim.api.nvim_win_get_cursor(last_win)
		local row = pos[1]
		local col = pos[2]
		vim.api.nvim_put(
			cb({
				buf = buf,
				path = path,
				row = row,
				col = col,
			}),
			"c",
			true,
			true
		)
		vim.cmd.startinsert()
	end
end

function M.put_last_file_name()
	M.put_with_last(function(ctx)
		return { string.format("%s", ctx.path) }
	end)
end

function M.put_last_file_line()
	M.put_with_last(function(ctx)
		return { string.format("%s:%i", ctx.path, ctx.row) }
	end)
end

function M.put_last_file_pos()
	M.put_with_last(function(ctx)
		return { string.format("%s:%i:%i", ctx.path, ctx.row, ctx.col) }
	end)
end

return M
