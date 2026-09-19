local M = {}

local config = require("plugins.toggleterm.config").panel
local ensure_dir = require("plugins.toggleterm.terms.ensure_dir").ensure_dir
local format_item = require("plugins.toggleterm.terms.format_item").format_item(false, false)
local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn
local visit = require("my.browser").visit

local states = {}
local highlight_namespace = vim.api.nvim_create_namespace("toggleterm-panel")
local empty_message = "No matching terminals"
local last_query = {}

-- URL icon matching adapted from MeanderingProgrammer/render-markdown.nvim.
local hyperlink_icon = "󰌹 "
local link_icons = {
	{ icon = "󰖟 ", pattern = "^http" },
	{ icon = " ", pattern = "apple%.com", kind = "url" },
	{ icon = "󰙯 ", pattern = "discord%.com", kind = "url" },
	{ icon = "󰊤 ", pattern = "github%.com", kind = "url" },
	{ icon = "󰮠 ", pattern = "gitlab%.com", kind = "url" },
	{ icon = "󰊭 ", pattern = "google%.com", kind = "url" },
	{ icon = " ", pattern = "ycombinator%.com", kind = "url" },
	{ icon = "󰌻 ", pattern = "linkedin%.com", kind = "url" },
	{ icon = " ", pattern = "microsoft%.com", kind = "url" },
	{ icon = " ", pattern = "neovim%.io", kind = "url" },
	{ icon = "󰑍 ", pattern = "reddit%.com", kind = "url" },
	{ icon = "󰒱 ", pattern = "slack%.com", kind = "url" },
	{ icon = "󰓌 ", pattern = "stackoverflow%.com", kind = "url" },
	{ icon = " ", pattern = "steampowered%.com", kind = "url" },
	{ icon = " ", pattern = "twitter%.com", kind = "url" },
	{ icon = "󰖬 ", pattern = "wikipedia%.org", kind = "url" },
	{ icon = " ", pattern = "x%.com", kind = "url" },
	{ icon = "󰗃 ", pattern = "youtube[^.]*%.com", kind = "url" },
	{ icon = "󰗃 ", pattern = "youtu%.be", kind = "url" },
}

local function url_icon(url)
	local selected
	for _, option in ipairs(link_icons) do
		local matches
		if option.kind == "url" then
			local prefix = url:match("^(.*)" .. option.pattern)
			if prefix then
				prefix = prefix:gsub("^https?://", "", 1):gsub("^www%.", "", 1)
				local last = prefix:sub(-1)
				matches = last == "" or last == "."
			end
		else
			matches = url:find(option.pattern) ~= nil
		end
		if matches and (not selected or #option.pattern > #selected.pattern) then
			selected = option
		end
	end
	return selected and selected.icon or hyperlink_icon
end

local function current_tab()
	return vim.api.nvim_get_current_tabpage()
end

local function valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function selected_instance(state)
	if not valid_win(state.win) then
		return state.selected_instance
	end
	local row = vim.api.nvim_win_get_cursor(state.win)[1]
	local selected = state.rows[row]
	return selected and selected.instance_count or state.selected_instance
end

local function release(state)
	if state.unsubscribe then
		state.unsubscribe()
		state.unsubscribe = nil
	end
	if state.refresh_timer then
		state.refresh_timer:stop()
		state.refresh_timer:close()
		state.refresh_timer = nil
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

local function status_age(term)
	if not term.status_changed_at then
		return nil
	end
	local minutes = math.floor(os.difftime(os.time(), term.status_changed_at) / 60)
	if minutes < 1 then
		return nil
	end
	if minutes < 60 then
		return minutes .. "m"
	end
	return math.floor(minutes / 60) .. "h"
end

local function create_rows(items, format, git_statuses, width)
	local root = { children = {}, items = {} }
	for _, item in ipairs(items) do
		local node = root
		for _, step in ipairs(path_steps(item.cwd)) do
			if not node.children[step.name] then
				node.children[step.name] = { children = {}, cwd = step.path, name = step.name, items = {} }
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
			elseif item.changed then
				highlight = "DiagnosticWarn"
			end
			local indent = string.rep("  ", depth)
			table.insert(rows, {
				instance_count = item.instance_count,
				item = item,
				text = indent .. format(item),
				status = item.status,
				highlight = highlight,
			})
			if item.title then
				table.insert(rows, {
					instance_count = item.instance_count,
					item = item,
					text = indent .. item.title,
					highlight = "Comment",
					title = true,
				})
			end
			for _, url in ipairs(item.term.url or {}) do
				table.insert(rows, {
					instance_count = item.instance_count,
					item = item,
					text = "  " .. url_icon(url) .. url,
					highlight = "Comment",
					url = url,
				})
			end
		end
	end
	local function append_directory(node, depth, name)
		local indent = string.rep("  ", depth)
		local icon = "󰉋 "
		local text = indent .. icon .. name
		local git_status = git_statuses[node.cwd]
		if git_status and git_status ~= "" then
			local padding = math.max(1, width - vim.fn.strdisplaywidth(text) - vim.fn.strdisplaywidth(git_status))
			text = text .. string.rep(" ", padding) .. git_status
		end
		table.insert(rows, {
			cwd = node.cwd,
			text = text,
			highlights = {
				{ start_col = #indent, end_col = #indent + #icon, group = "NeoTreeDirectoryIcon" },
				{ start_col = #indent + #icon, end_col = -1, group = "NeoTreeDirectoryName" },
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
			append_items(child, depth)
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
	local only_directory = common ~= root and #common.items == #items and vim.tbl_isempty(common.children)
	local home = vim.env.HOME and vim.fs.normalize(vim.env.HOME) or nil
	if only_directory and common.cwd ~= home and common.cwd ~= "/" then
		local parent = vim.fs.dirname(common.cwd)
		append_directory({ cwd = parent }, 0, display_path(parent))
		append_directory(common, 1, common.name)
		append_items(common, 1)
	elseif common ~= root then
		append_directory(common, 0, display_path(common.cwd))
		append(common, 1)
		append_items(common, 0)
	else
		append(root, 0)
	end

	local status_column = 0
	for _, row in ipairs(rows) do
		if row.status then
			status_column = math.max(status_column, vim.fn.strdisplaywidth(row.text))
		end
	end
	for _, row in ipairs(rows) do
		if row.status then
			local padding = status_column - vim.fn.strdisplaywidth(row.text) + 1
			local age = status_age(row.item.term)
			local status = age and row.status .. " " .. age or row.status
			row.text = row.text .. string.rep(" ", padding) .. "(" .. status .. ")"
		end
	end
	return rows
end

local refresh

local function update_git_status(state, dir)
	local cached = state.git_statuses[dir]
	if cached and os.time() - cached.checked_at < 30 then
		return
	end
	state.git_statuses[dir] = { checked_at = os.time(), pending = true }
	vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = dir, text = true }, function(root_result)
		local root = vim.trim(root_result.stdout or "")
		if root_result.code ~= 0 or vim.fs.normalize(root) ~= vim.fs.normalize(dir) then
			vim.schedule(function()
				state.git_statuses[dir] = { checked_at = os.time(), value = false }
			end)
			return
		end
		vim.system(
			{ "starship", "module", "git_status" },
			{ cwd = dir, text = true, env = { NO_COLOR = "1" } },
			function(result)
				local status = vim.trim(result.stdout or ""):gsub("\27%[[%d;]*m", ""):gsub("^%[(.*)%]$", "%1")
				vim.schedule(function()
					state.git_statuses[dir] = { checked_at = os.time(), value = result.code == 0 and status or false }
					refresh(state)
				end)
			end
		)
	end)
end

local function render(state)
	if states[state.tab] ~= state or not valid_buf(state.buf) then
		return
	end

	local instance_count = selected_instance(state)
	local items = state.deps.items(state.query)
	local git_statuses = {}
	for dir, cached in pairs(state.git_statuses) do
		git_statuses[dir] = cached.value
	end
	local width = valid_win(state.win) and vim.api.nvim_win_get_width(state.win) or state.deps.width
	local rows = create_rows(items, state.deps.format, git_statuses, width)
	for _, row in ipairs(rows) do
		if row.cwd then
			update_git_status(state, row.cwd)
		end
	end
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
	state.selected_instance = instance_count

	if not valid_win(state.win) then
		return
	end
	local target = 1
	for index, row in ipairs(rows) do
		if (instance_count and row.instance_count == instance_count) or (not instance_count and row.item) then
			target = index
			break
		end
	end
	vim.api.nvim_win_set_cursor(state.win, { math.min(target, #lines), 0 })
end

refresh = function(state)
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
	state.selected_instance = selected.instance_count
	if selected.url then
		visit(selected.url)
	elseif selected.item then
		selected.item.term:focus()
	else
		ensure_dir(selected.cwd)
	end
end

local function restart_selected(state)
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if selected and selected.item then
		selected.item.term:restart()
	end
end

local function kill_selected(state)
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if selected and selected.item then
		selected.item.term:kill()
	end
end

local function create_in_selected_dir(state)
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected then
		return
	end
	local dir = selected.item and selected.item.cwd or selected.cwd
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
		git_statuses = {},
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

	state.refresh_timer = vim.uv.new_timer()
	state.refresh_timer:start(
		60000,
		60000,
		vim.schedule_wrap(function()
			refresh(state)
		end)
	)

	state.unsubscribe = deps.subscribe(function(event)
		if
			event.type == "create"
			or event.type == "focus"
			or event.type == "status"
			or event.type == "title"
			or event.type == "url"
			or event.type == "cwd"
			or event.type == "detach"
		then
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
