local M = {}

local states = {}
local empty_message = "No matching terminals"

local function current_tab()
	return vim.api.nvim_get_current_tabpage()
end

local function valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function selected_hash(state)
	if not valid_win(state.win) then
		return state.selected_hash
	end
	local row = vim.api.nvim_win_get_cursor(state.win)[1]
	local selected = state.rows[row]
	return selected and selected.hash or state.selected_hash
end

local function release(state)
	if state.unsubscribe then
		state.unsubscribe()
		state.unsubscribe = nil
	end
	if states[state.tab] == state then
		states[state.tab] = nil
	end
end

local function close(state)
	release(state)
	if valid_win(state.win) then
		vim.api.nvim_win_close(state.win, false)
	end
	if valid_buf(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end
end

local function render(state)
	if states[state.tab] ~= state or not valid_buf(state.buf) then
		return
	end

	local hash = selected_hash(state)
	local items = state.deps.items(state.query)
	local rows = vim.tbl_map(function(item)
		return {
			hash = item.hash,
			item = item,
			text = state.deps.format(item),
		}
	end, items)
	local lines = vim.tbl_map(function(row)
		return row.text
	end, rows)
	if #lines == 0 then
		lines = { empty_message }
	end

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	state.rows = rows
	state.selected_hash = hash

	if not valid_win(state.win) then
		return
	end
	local target = 1
	if hash then
		for index, row in ipairs(rows) do
			if row.hash == hash then
				target = index
				break
			end
		end
	end
	vim.api.nvim_win_set_cursor(state.win, { math.min(target, #lines), 0 })
end

local function refresh(state)
	if state.refresh_pending then
		return
	end
	state.refresh_pending = true
	vim.schedule(function()
		state.refresh_pending = false
		render(state)
	end)
end

local function focus_selected(state)
	local row = vim.api.nvim_win_get_cursor(state.win)[1]
	local selected = state.rows[row]
	if selected then
		state.selected_hash = selected.hash
		selected.item.term.focus()
	end
end

local function open(query, deps)
	local tab = current_tab()
	vim.cmd("topleft 40vsplit")
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)

	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].filetype = "toggleterm-panel"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.wo[win].cursorline = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].winfixwidth = true
	vim.wo[win].wrap = false

	local state = {
		tab = tab,
		win = win,
		buf = buf,
		query = vim.deepcopy(query or {}),
		deps = deps,
		rows = {},
	}
	states[tab] = state

	vim.keymap.set("n", "<CR>", function()
		focus_selected(state)
	end, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "q", function()
		close(state)
	end, { buffer = buf, silent = true, nowait = true })
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			release(state)
		end,
	})

	state.unsubscribe = deps.subscribe(function(event)
		if event.type == "create" or event.type == "focus" or event.type == "status" or event.type == "detach" then
			refresh(state)
		end
	end)
	render(state)
end

function M.toggle(query, deps)
	local tab = current_tab()
	local state = states[tab]
	if state and valid_win(state.win) then
		close(state)
		return
	end
	if state then
		release(state)
	end
	open(query, deps)
end

function M.open(query, deps)
	local tab = current_tab()
	local state = states[tab]
	if state and valid_win(state.win) then
		vim.api.nvim_set_current_win(state.win)
		return
	end
	if state then
		release(state)
	end
	open(query, deps)
end

return M
