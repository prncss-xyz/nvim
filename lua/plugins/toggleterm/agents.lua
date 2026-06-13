local M = {}

local function diagnostic_position(bufnr, diagnostic)
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")
	return string.format("@%s :L%d:C%d", path, (diagnostic.lnum or 0) + 1, (diagnostic.col or 0) + 1)
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

local function diagnostic_in_cwd(diagnostic, fallback_bufnr)
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

function M.diagnostics()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostics = vim.tbl_filter(function(diagnostic)
		return diagnostic_in_cwd(diagnostic, bufnr)
	end, vim.diagnostic.get())
	if #diagnostics == 0 then
		vim.notify("No diagnostics found in current working directory", vim.log.levels.WARN)
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

	local lines = {
		cr = true,
		"fix these diagnostics",
	}

	for index, diagnostic in ipairs(diagnostics) do
		if index > 1 then
			table.insert(lines, "")
		end
		vim.list_extend(lines, diagnostic_lines(diagnostic, bufnr))
	end

	require("plugins.toggleterm.terms").send_lines(key, lines)
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

local function get_current_diagnostic(bufnr)
	local cursor = get_buf_cursor(bufnr)
	local row = cursor and (cursor[1] - 1) or nil
	local col = cursor and cursor[2] or nil
	local diagnostics = row and vim.diagnostic.get(bufnr, { lnum = row }) or {}

	if row and col then
		for _, diagnostic in ipairs(diagnostics) do
			local start_row = diagnostic.lnum or row
			local start_col = diagnostic.col or 0
			local end_row = diagnostic.end_lnum or start_row
			local end_col = diagnostic.end_col or (start_col + 1)

			local after_start = row > start_row or (row == start_row and col >= start_col)
			local before_end = row < end_row or (row == end_row and col < end_col)
			if after_start and before_end then
				return diagnostic
			end
		end

		if #diagnostics > 0 then
			table.sort(diagnostics, function(a, b)
				return math.abs((a.col or 0) - col) < math.abs((b.col or 0) - col)
			end)
			return diagnostics[1]
		end
	end

	local all = vim.diagnostic.get(bufnr)
	if #all == 0 then
		return nil
	end

	if row == nil or col == nil then
		return all[1]
	end

	table.sort(all, function(a, b)
		local a_row = a.lnum or 0
		local b_row = b.lnum or 0
		local a_col = a.col or 0
		local b_col = b.col or 0
		local a_dist = math.abs(a_row - row) * 10000 + math.abs(a_col - col)
		local b_dist = math.abs(b_row - row) * 10000 + math.abs(b_col - col)
		return a_dist < b_dist
	end)

	return all[1]
end

function M.diagnostic()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostic = get_current_diagnostic(bufnr)
	if not diagnostic then
		vim.notify("No diagnostic found", vim.log.levels.WARN)
		return
	end

	require("plugins.toggleterm.terms").send_lines(key, {
		cr = false,
		"fix this diagnostic",
		diagnostic_position(bufnr, diagnostic),
		diagnostic.message or "",
	})
end

function M.file_diagnostics()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()
	local diagnostics = vim.diagnostic.get(bufnr)
	if #diagnostics == 0 then
		vim.notify("No diagnostics found", vim.log.levels.WARN)
		return
	end

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

	local lines = {
		cr = false,
		"fix these diagnostics",
	}

	for _, diagnostic in ipairs(diagnostics) do
		table.insert(lines, diagnostic_position(bufnr, diagnostic))
		table.insert(lines, diagnostic.message or "")
	end

	require("plugins.toggleterm.terms").send_lines(key, lines)
end

function M.current_file()
	return string.format("@%s", vim.fn.expand("%:."))
end

function M.current_line()
	return string.format("@%s :L%d", vim.fn.expand("%:."), vim.fn.line("."))
end

function M.current_position()
	return string.format("@%s :L%d:C%d", vim.fn.expand("%:."), vim.fn.line("."), vim.fn.col("."))
end

function M.send_current_position()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end
	require("plugins.toggleterm.terms").send_lines(key, { M.current_position() })
end

function M.send_current_file()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end
	require("plugins.toggleterm.terms").send_lines(key, { M.current_file() .. " " })
end

function M.prompt()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end
	local prompts = require("plugins.toggleterm.config").prompts
	local choices = vim.tbl_keys(prompts)
	vim.ui.select(choices, {
		prompt = "Select prompt: ",
	}, function(choice)
		if not choice then
			return
		end

		local prompt_fn = prompts[choice]
		local prompt_data = prompt_fn()

		require("plugins.toggleterm.terms").send_lines(key, prompt_data)
	end)
end

function M.new()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end
	local command = require("plugins.toggleterm.config").new[key]
	if not command then
		return
	end
	require("plugins.toggleterm.terms").send_lines(key, {
		cr = "true",
		"/" .. command,
	})
end

return M
