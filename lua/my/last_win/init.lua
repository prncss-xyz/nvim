local M = {}

-- TODO: selection, workspace diagnostics

local terms = require("plugins.toggleterm.terms")

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

function M.put_with_last(cb, key)
	terms.with_tag(key, function()
		local last_win = M.get_last_file_win()
		if last_win then
			local bufnr = vim.api.nvim_win_get_buf(last_win)
			local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
			local pos = vim.api.nvim_win_get_cursor(last_win)
			local row = pos[1]
			local col = pos[2]
			vim.api.nvim_put(
				cb({
					bufnr = bufnr,
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
	end)
end

function M.put_last_file_name()
	M.put_with_last(function(ctx)
		return { string.format("%s ", ctx.path) }
	end, "agent")
end

function M.put_last_file_line()
	M.put_with_last(function(ctx)
		return { string.format("%s:%i ", ctx.path, ctx.row) }
	end, "agent")
end

function M.put_last_file_pos()
	M.put_with_last(function(ctx)
		return { string.format("%s:%i:%i ", ctx.path, ctx.row, ctx.col) }
	end, "agent")
end

function M.put_diagnostic_prompt()
	M.put_with_last(function(ctx)
		return require("my.last_win.diagnostics").get_diagnostic_prompt(ctx.bufnr)
	end, "agent")
end

function M.put_file_diagnostics_prompt()
	M.put_with_last(function(ctx)
		return require("my.last_win.diagnostics").get_file_diagnostics_prompt(ctx.bufnr)
	end, "agent")
end

function M.get_selection(bufnr)
	-- exit visual/select mode in the target buffer so marks are set
	if vim.api.nvim_get_current_buf() == bufnr and vim.fn.mode():match("[vV\22sS\19]") then
		vim.cmd([[noautocmd normal! \<Esc>]])
	end

	local start = vim.api.nvim_buf_get_mark(bufnr, "<")
	local end_ = vim.api.nvim_buf_get_mark(bufnr, ">")
	local start_row, start_col = start[1] - 1, start[2]
	local end_row, end_col = end_[1] - 1, end_[2] + 1

	-- for linewise visual mode, extend end_col to line end
	if vim.fn.visualmode() == "V" then
		end_col = -1
	end

	local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")

	local res = { string.format("%s:%i:%i", path, start_row + 1, start_col + 1) }
	vim.list_extend(res, lines)
	return lines
end

function M.put_selection_to_term(key)
	M.put_with_last(function(ctx)
		return M.get_selection(ctx.bufnr)
	end, key)
end

return M
