local M = {}
local panel_utils = require("neoterm.helpers.panel")

local state
local namespace = vim.api.nvim_create_namespace("toggleterm-auto-panel")

local function close()
	if state then
		state.unsubscribe()
		state.unsubscribe_auto()
		if vim.api.nvim_win_is_valid(state.win) then
			vim.api.nvim_win_close(state.win, false)
		end
	end
	state = nil
end

local function create_rows(upcoming, filter)
	local tasks = panel_utils.filter_rows(
		vim.tbl_map(function(item)
			local step = item.step.name .. (item.variant and ":" .. item.variant or "")
			local checkout = item.cwd and vim.fs.basename(item.cwd)
				or "ambiguous: " .. table.concat(vim.tbl_map(vim.fs.basename, item.checkouts), ", ")
			return {
				text = table.concat(item.task.parts, "/") .. "  " .. step .. "  → " .. checkout,
				parts = item.task.parts,
				details = "  " .. step .. "  → " .. checkout,
				file = item.file,
				ambiguous = item.cwd == nil,
			}
		end, upcoming),
		filter
	)
	local rows = {}
	local previous = {}
	for _, task in ipairs(tasks) do
		local shared = true
		for depth = 1, #task.parts - 1 do
			local part = task.parts[depth]
			shared = shared and previous[depth] == part
			if not shared then
				table.insert(rows, { text = string.rep("  ", depth - 1) .. part .. "/", directory = true })
			end
		end
		task.text = string.rep("  ", #task.parts - 1) .. task.parts[#task.parts] .. task.details
		table.insert(rows, task)
		previous = task.parts
	end
	return rows, #tasks
end

local function render()
	if not state or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	local auto = require("neoterm.terms.artifacts.auto")
	local rows, count = create_rows(auto.upcoming(), state.filter)
	table.insert(rows, 1, { text = auto.auto_status() or "auto mode off", header = true })
	if #rows == 1 then
		table.insert(rows, { text = "No upcoming auto steps" })
	end
	table.insert(rows, { text = "count: " .. count })
	state.rows = rows
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(
		state.buf,
		0,
		-1,
		false,
		vim.tbl_map(function(row)
			return row.text
		end, rows)
	)
	vim.bo[state.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
	for index, row in ipairs(rows) do
		vim.api.nvim_buf_set_extmark(state.buf, namespace, index - 1, 0, {
			end_col = #row.text,
			hl_group = row.ambiguous and "DiagnosticWarn"
				or row.file and "DiagnosticInfo"
				or row.directory and "NeoTreeDirectoryName"
				or "Comment",
		})
	end
	panel_utils.highlight_filter(state, namespace)
end

local function open_selected()
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if selected and selected.file then
		require("neoterm.helpers.file_windows").open(selected.file)
	end
end

local function filter_panel()
	local panel = state
	panel_utils.open_filter(panel, {
		render = render,
		valid = function()
			return state == panel
		end,
		same = function(row, selected)
			return row.file == selected.file and row.text == selected.text
		end,
		accept = open_selected,
	})
end

function M.toggle()
	if state and vim.api.nvim_win_is_valid(state.win) then
		close()
		return
	end
	local config = require("neoterm.config")
	vim.cmd(string.format("topleft %dvsplit", config.auto_panel.width))
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)
	local function refresh()
		if state and state.buf == buf then
			render()
		end
	end
	state = {
		win = win,
		buf = buf,
		rows = {},
		unsubscribe = require("neoterm.terms.artifacts.tasks").subscribe(refresh),
		unsubscribe_auto = require("neoterm.terms.artifacts.auto").subscribe_auto(refresh),
	}
	local panel = state
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "toggleterm-auto-panel"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.wo[win].cursorline = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].winfixwidth = true
	vim.wo[win].wrap = false
	panel_utils.bind(panel, config.auto_panel.keybindings, {
		filter = filter_panel,
		open = open_selected,
		close = close,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			if state == panel then
				panel.unsubscribe()
				panel.unsubscribe_auto()
				state = nil
			end
		end,
	})
	render()
	for line, row in ipairs(state.rows) do
		if row.file then
			vim.api.nvim_win_set_cursor(win, { line, #(row.text:match("^%s*") or "") })
			break
		end
	end
end

return M
