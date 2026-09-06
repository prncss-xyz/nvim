local M = {}

local config = require("plugins.toggleterm.config").panel
local ensure_dir = require("plugins.toggleterm.terms.ensure_dir").ensure_dir
local format_item = require("plugins.toggleterm.terms.format_item").format_item(false)
local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn

local states = {}
local highlight_namespace = vim.api.nvim_create_namespace("toggleterm-panel")
local empty_message = "No matching terminals"
local last_query = {}

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

local function display_path(dir)
	local home = vim.env.HOME
	if dir == home then
		return "~"
	end
	if home and dir:sub(1, #home + 1) == home .. "/" then
		return "~/" .. dir:sub(#home + 2)
	end
	return dir
end

local function path_steps(dir)
	local home = vim.env.HOME
	local root = dir:sub(1, 1) == "/" and "/" or nil
	local path = root
	local rest = root and dir:sub(2) or dir

	if home and (dir == home or dir:sub(1, #home + 1) == home .. "/") then
		root = "~"
		path = home
		rest = dir:sub(#home + 2)
	end

	local steps = {}
	if root then
		table.insert(steps, { name = root, path = path })
	end
	for name in rest:gmatch("[^/]+") do
		path = path == "/" and path .. name or (path and path .. "/" .. name or name)
		table.insert(steps, { name = name, path = path })
	end
	return steps
end

local function create_rows(items, format)
	local root = { children = {}, items = {} }
	for _, item in ipairs(items) do
		local node = root
		for _, step in ipairs(path_steps(item.dir)) do
			if not node.children[step.name] then
				node.children[step.name] = { children = {}, dir = step.path, name = step.name, items = {} }
			end
			node = node.children[step.name]
		end
		table.insert(node.items, item)
	end

	local rows = {}
	local function append_items(node, depth)
		table.sort(node.items, function(a, b)
			local a_key = a.key or ""
			local b_key = b.key or ""
			if a_key ~= b_key then
				return a_key < b_key
			end
			return (a.instance_count or 0) < (b.instance_count or 0)
		end)
		for _, item in ipairs(node.items) do
			local highlight = "NeoTreeFileName"
			if item.status == "failure" then
				highlight = "DiagnosticError"
			elseif item.seen == false then
				highlight = "DiagnosticWarn"
			end
			table.insert(rows, {
				hash = item.hash,
				item = item,
				text = string.rep("  ", depth) .. format(item),
				status = item.status,
				highlight = highlight,
			})
		end
	end
	local function append_directory(node, depth, name)
		local indent = string.rep("  ", depth)
		table.insert(rows, {
			dir = node.dir,
			text = indent .. "󰉋 " .. name,
			highlights = {
				{ group = "NeoTreeDirectoryIcon", start_col = #indent, end_col = #indent + #"󰉋" },
				{ group = "NeoTreeDirectoryName", start_col = #indent + #"󰉋 ", end_col = -1 },
			},
		})
	end
	local function append(node, depth)
		local names = vim.tbl_keys(node.children)
		table.sort(names)
		for _, name in ipairs(names) do
			local child = node.children[name]
			append_directory(child, depth, child.name)
			append(child, depth + 1)
			append_items(child, depth + 1)
		end
	end

	local common = root
	while #common.items == 0 do
		local names = vim.tbl_keys(common.children)
		if #names ~= 1 then
			break
		end
		common = common.children[names[1]]
	end
	if common ~= root then
		append_directory(common, 0, display_path(common.dir))
		append(common, 1)
		append_items(common, 1)
	else
		append(root, 0)
	end

	local status_column = 0
	for _, row in ipairs(rows) do
		if row.item then
			status_column = math.max(status_column, vim.fn.strdisplaywidth(row.text))
		end
	end
	for _, row in ipairs(rows) do
		if row.item then
			local padding = status_column - vim.fn.strdisplaywidth(row.text) + 1
			row.text = row.text .. string.rep(" ", padding) .. "(" .. row.status .. ")"
		end
	end
	return rows
end

local function render(state)
	if states[state.tab] ~= state or not valid_buf(state.buf) then
		return
	end

	local hash = selected_hash(state)
	local items = state.deps.items(state.query)
	local rows = create_rows(items, state.deps.format)
	local lines = vim.tbl_map(function(row)
		return row.text
	end, rows)
	if #lines == 0 then
		lines = { empty_message }
	end

	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.buf, highlight_namespace, 0, -1)
	for index, row in ipairs(rows) do
		if row.highlight then
			vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, index - 1, 0, {
				end_col = #row.text,
				hl_group = row.highlight,
			})
		end
		for _, highlight in ipairs(row.highlights or {}) do
			vim.api.nvim_buf_set_extmark(state.buf, highlight_namespace, index - 1, highlight.start_col, {
				end_col = highlight.end_col == -1 and #row.text or highlight.end_col,
				hl_group = highlight.group,
			})
		end
	end
	state.rows = rows
	state.selected_hash = hash

	if not valid_win(state.win) then
		return
	end
	local target = 1
	for index, row in ipairs(rows) do
		if (hash and row.hash == hash) or (not hash and row.item) then
			target = index
			break
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
	if not selected then
		return
	end
	state.selected_hash = selected.hash
	if selected.item then
		selected.item.term.focus()
	else
		ensure_dir(selected.dir)
	end
end

local function restart_selected(state)
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if selected and selected.item then
		selected.item.term.restart()
	end
end

local function kill_selected(state)
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if selected and selected.item then
		selected.item.term.kill()
	end
end

local function create_in_selected_dir(state)
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected then
		return
	end
	local dir = selected.item and selected.item.dir or selected.dir
	if dir and state.deps.create_in_dir then
		state.deps.create_in_dir(dir)
	end
end

local function get_dependencies(history, subscribe, create_in_dir)
	return {
		items = function(query)
			return history.filter(get_query_fn(query))
		end,
		subscribe = subscribe,
		create_in_dir = create_in_dir,
		format = format_item,
		width = config.width,
	}
end

local function open(query, history, subscribe, create_in_dir)
	local deps = get_dependencies(history, subscribe, create_in_dir)
	local tab = current_tab()
	vim.cmd(string.format("topleft %dvsplit", deps.width))
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
	vim.keymap.set("n", "r", function()
		restart_selected(state)
	end, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "x", function()
		kill_selected(state)
	end, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "n", function()
		create_in_selected_dir(state)
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

function M.toggle(query, history, subscribe, create_in_dir)
	last_query = vim.deepcopy(query or {})
	local tab = current_tab()
	local state = states[tab]
	if state and valid_win(state.win) then
		close(state)
		return
	end
	if state then
		release(state)
	end
	open(last_query, history, subscribe, create_in_dir)
end

function M.open(history, subscribe, create_in_dir)
	local tab = current_tab()
	local state = states[tab]
	if state and valid_win(state.win) then
		vim.api.nvim_set_current_win(state.win)
		return
	end
	if state then
		release(state)
	end
	open(last_query, history, subscribe, create_in_dir)
end

return M
