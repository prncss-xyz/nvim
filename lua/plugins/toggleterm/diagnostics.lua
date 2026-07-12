local M = {}

local function diagnostic_position(bufnr, diagnostic)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	return string.format("@%s:%d:%d", path, (diagnostic.lnum or 0) + 1, (diagnostic.col or 0) + 1)
end

local function get_diagnostic_bufnr(diagnostic, fallback_bufnr)
	local bufnr = diagnostic.bufnr or fallback_bufnr
	if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
		return bufnr
	end
	return fallback_bufnr
end

local function diagnostic_text(bufnr, diagnostic)
	local start_row = diagnostic.lnum or 0
	local start_col = diagnostic.col or 0
	local end_row = diagnostic.end_lnum or start_row
	local end_col = diagnostic.end_col

	if end_col == nil or (start_row == end_row and end_col <= start_col) then
		local line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ""
		end_col = math.min(#line, start_col + 1)
	end

	local text = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
	if vim.tbl_isempty(text) then
		text = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)
	end

	return table.concat(text, "\n")
end

local function filter_diagnostics(diagnostic, fallback_bufnr)
	local bufnr = get_diagnostic_bufnr(diagnostic, fallback_bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		return false
	end

	local cwd = vim.fs.normalize(vim.fn.getcwd())
	local path = vim.fs.normalize(name)
	return path == cwd or vim.startswith(path, cwd .. "/")
end

local function diagnostic_lines(diagnostic, fallback_bufnr)
	local bufnr = get_diagnostic_bufnr(diagnostic, fallback_bufnr)
	return {
		diagnostic_position(bufnr, diagnostic),
		diagnostic.message or "",
		diagnostic_text(bufnr, diagnostic),
	}
end

local function get_buf_cursor(bufnr)
	local current_win = vim.api.nvim_get_current_win()
	if vim.api.nvim_win_get_buf(current_win) == bufnr then
		return vim.api.nvim_win_get_cursor(current_win)
	end

	for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
		if vim.api.nvim_win_is_valid(winid) then
			return vim.api.nvim_win_get_cursor(winid)
		end
	end
end

-- Returns a list containing the next diagnostic in the window showing bufnr,
-- starting inclusively from the current cursor position. The list has at most
-- one diagnostic; it is empty when the cursor is at or past the last diagnostic.
local function next_window_diagnostics(bufnr)
	local cursor = get_buf_cursor(bufnr)
	if not cursor then
		return {}
	end

	local row = cursor[1] - 1
	local col = cursor[2]
	local diagnostics = vim.diagnostic.get(bufnr)
	table.sort(diagnostics, function(a, b)
		local a_lnum = a.lnum or 0
		local b_lnum = b.lnum or 0
		if a_lnum ~= b_lnum then
			return a_lnum < b_lnum
		end

		local a_col = a.col or 0
		local b_col = b.col or 0
		if a_col ~= b_col then
			return a_col < b_col
		end

		return (a.severity or math.huge) < (b.severity or math.huge)
	end)

	for _, diagnostic in ipairs(diagnostics) do
		local start_row = diagnostic.lnum or 0
		local start_col = diagnostic.col or 0
		if start_row > row or (start_row == row and start_col >= col) then
			return { diagnostic }
		end
	end

	return {}
end

-- Sends a prompt to the agent terminal asking it to fix the selected diagnostics.
-- scope == nil or "project": all diagnostics whose buffer lives under the cwd (the historical default)
-- scope == "file": all diagnostics in the current buffer
-- scope == "next": the next diagnostic in the current window, starting inclusively from the cursor
function M.get_diagnostics(bufnr, scope)
	local diagnostics
	local empty_message

	if scope == "next" then
		diagnostics = next_window_diagnostics(bufnr)
		empty_message = "No diagnostic after the cursor in the current window"
	elseif scope == "file" then
		diagnostics = vim.diagnostic.get(bufnr)
		empty_message = "No diagnostics in the current buffer"
	else
		diagnostics = vim.tbl_filter(function(diagnostic)
			return filter_diagnostics(diagnostic, bufnr)
		end, vim.diagnostic.get())
		empty_message = "No diagnostics found in current working directory"
	end

	if #diagnostics == 0 then
		vim.notify(empty_message, vim.log.levels.WARN)
		return
	end

	table.sort(diagnostics, function(a, b)
		local a_bufnr = get_diagnostic_bufnr(a, bufnr) or 0
		local b_bufnr = get_diagnostic_bufnr(b, bufnr) or 0
		if a_bufnr ~= b_bufnr then
			return a_bufnr < b_bufnr
		end

		local a_lnum = a.lnum or 0
		local b_lnum = b.lnum or 0
		if a_lnum ~= b_lnum then
			return a_lnum < b_lnum
		end

		local a_col = a.col or 0
		local b_col = b.col or 0
		if a_col ~= b_col then
			return a_col < b_col
		end

		return (a.severity or math.huge) < (b.severity or math.huge)
	end)

	local lines = {}

	for index, diagnostic in ipairs(diagnostics) do
		if index > 1 then
			table.insert(lines, "")
		end
		vim.list_extend(lines, diagnostic_lines(diagnostic, bufnr))
	end

	local payload = table.concat(lines, "\n")

	return payload
end

return M
