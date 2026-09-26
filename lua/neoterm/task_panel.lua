local M = {}

local get_last_file_win = require("neoterm.helpers.win_history").get_last_file_win

local state
local namespace = vim.api.nvim_create_namespace("toggleterm-task-panel")
local events = vim.api.nvim_create_augroup("toggleterm-task-panel-focus", { clear = true })

local function default_root(artifacts)
	local path = vim.api.nvim_buf_get_name(0)
	if path ~= "" and vim.fs.relpath(artifacts, vim.fs.abspath(path)) then
		return artifacts
	end

	local projects = require("neoterm.config").dirs.projects
	local relative = vim.fs.relpath(projects, vim.fs.abspath(vim.fn.getcwd()))
	if relative == nil or relative == "." then
		return artifacts
	end
	local project = assert(vim.split(relative, "/", { plain = true, trimempty = true })[1])
	return vim.fs.joinpath(artifacts, project)
end

local function close()
	vim.api.nvim_clear_autocmds({ group = events })
	if state and state.unsubscribe then
		state.unsubscribe()
	end
	if state and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, false)
	end
	state = nil
end

local function has_prefix(parts, prefix)
	for index, part in ipairs(prefix) do
		if parts[index] ~= part then
			return false
		end
	end
	return true
end

local function unknown_status(status, status_names)
	return not status_names[status] and not vim.startswith(status, "ERROR:")
end

local function create_rows(tasks, statuses, status_names, root_parts)
	local result = {}
	local mode_statuses = {}
	for _, status in ipairs(statuses) do
		mode_statuses[status] = true
	end
	local error_groups = { { name = "ERROR:UNKNOWN TAG", broken = true } }
	local seen_errors = {}
	for _, task in ipairs(tasks) do
		local status = task.status
		if vim.startswith(status, "ERROR:") and not seen_errors[status] and not mode_statuses[status] then
			seen_errors[status] = true
			table.insert(error_groups, { name = status })
		end
	end
	table.sort(error_groups, function(left, right)
		return left.name < right.name
	end)
	local groups = error_groups
	for _, status in ipairs(statuses) do
		table.insert(groups, { name = status })
	end
	for _, group in ipairs(groups) do
		local root = { children = {} }
		for _, task in ipairs(tasks) do
			local matches = group.broken and unknown_status(task.status, status_names)
				or not group.broken and task.status == group.name
			if matches and #task.parts > #root_parts and has_prefix(task.parts, root_parts) then
				local node = root
				for index = #root_parts + 1, #task.parts do
					local name = task.parts[index]
					node.children[name] = node.children[name] or { name = name, children = {} }
					node = node.children[name]
				end
				node.task = task
			end
		end

		if not vim.tbl_isempty(root.children) then
			table.insert(result, {
				text = group.name .. ":",
				status = group.name,
				broken = group.broken,
				parts = {},
				status_heading = true,
			})
			local function append(node, depth, parts)
				local names = vim.tbl_keys(node.children)
				table.sort(names)
				for _, name in ipairs(names) do
					local child = node.children[name]
					local child_parts = vim.deepcopy(parts)
					table.insert(child_parts, name)
					local icon = child.task and child.task.flat and "󰈙" or "󰉋"
					table.insert(result, {
						text = string.rep("  ", depth) .. icon .. " " .. name,
						status = group.name,
						broken = group.broken,
						parts = child_parts,
						has_children = not vim.tbl_isempty(child.children),
						cwd = child.task and child.task.cwd or nil,
						task = child.task,
					})
					append(child, depth + 1, child_parts)
				end
			end
			append(root, 0, vim.deepcopy(root_parts))
		end
	end
	return result
end

local function active_task_line()
	local path = state.active_file
	if not path or path == "" then
		return nil
	end
	local selected, depth
	for index, row in ipairs(state.rows) do
		local task = row.task
		if task and (task.flat and task.files[path] or (not task.flat and vim.startswith(path, task.cwd .. "/"))) then
			if not depth or #task.parts > depth then
				selected, depth = index, #task.parts
			end
		end
	end
	return selected
end

local function render()
	if not state or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	local config = require("neoterm.config")
	state.tasks = require("neoterm.terms.artifacts.tasks").get()
	local relative_root = assert(vim.fs.relpath(state.artifacts, state.root))
	local root_parts = relative_root == "." and {} or vim.split(relative_root, "/", { plain = true })
	local statuses = assert(config.tasks.modes[state.mode], "Unknown task panel mode: " .. state.mode)
	local status_names = {}
	for _, mode_statuses in pairs(config.tasks.modes) do
		for _, status in ipairs(mode_statuses) do
			status_names[status] = true
		end
	end
	state.status_names = status_names
	state.rows = create_rows(state.tasks, statuses, status_names, root_parts)
	table.insert(state.rows, 1, { text = string.format("%s [%s]", relative_root, state.mode), root = true })
	if #state.rows == 1 then
		table.insert(state.rows, { text = "No artifact tasks" })
	end
	if state.filter and state.filter ~= "" then
		local words = vim.split(state.filter, "%s+", { trimempty = true })
		state.rows = vim.tbl_filter(function(row)
			for _, word in ipairs(words) do
				if not row.text:find(word, 1, true) then
					return false
				end
			end
			return true
		end, state.rows)
	end
	local lines = vim.tbl_map(function(row)
		return row.text
	end, state.rows)
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
	for index, row in ipairs(state.rows) do
		vim.api.nvim_buf_set_extmark(state.buf, namespace, index - 1, 0, {
			end_col = #row.text,
			hl_group = row.root and "Comment"
				or (row.status_heading and "DiagnosticWarn")
				or (row.task and "DiagnosticInfo")
				or "NeoTreeDirectoryName",
		})
	end
	if state.filter ~= nil and #state.rows > 0 then
		state.filter_index = math.min(state.filter_index or 1, #state.rows)
		vim.api.nvim_buf_set_extmark(state.buf, namespace, state.filter_index - 1, 0, {
			line_hl_group = "Visual",
		})
	elseif state.filter == nil then
		local line = active_task_line()
		if line then
			vim.api.nvim_buf_set_extmark(state.buf, namespace, line - 1, 0, {
			line_hl_group = "Visual",
			})
		end
	end
end

function M.list_tasks()
	local tasks = vim.list_extend({}, require("neoterm.terms.artifacts.tasks").get())
	table.sort(tasks, function(left, right)
		return table.concat(left.parts, "/") < table.concat(right.parts, "/")
	end)
	return tasks
end

local function selected_task(selected)
	return selected.task
end

local function open_selected()
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected then
		return
	end
	local latest = require("neoterm.terms.artifacts.tasks").latest(state.tasks, function(task)
		if selected.broken then
			if not unknown_status(task.status, state.status_names) then
				return false
			end
		elseif task.status ~= selected.status then
			return false
		end
		for index, part in ipairs(selected.parts) do
			if task.parts[index] ~= part then
				return false
			end
		end
		return true
	end)
	local target_win = get_last_file_win()
	if not target_win or not vim.api.nvim_win_is_valid(target_win) then
		return
	end
	if latest then
		if latest.bufnr then
			vim.api.nvim_win_set_buf(target_win, latest.bufnr)
		else
			vim.api.nvim_win_call(target_win, function()
				require("neoterm.config").create(vim.fn.fnameescape(latest.path))
			end)
		end
		vim.api.nvim_set_current_win(target_win)
	elseif selected.task then
		local task = assert(selected_task(selected), "Selected artifact task not found")
		vim.api.nvim_win_call(target_win, function()
			require("neoterm.config").create(vim.fn.fnameescape(vim.fs.joinpath(task.cwd, "index.md")))
		end)
		vim.api.nvim_set_current_win(target_win)
	end
end

local function create_task()
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected then
		return
	end
	local directory
	if selected.root then
		directory = state.root
	elseif selected.task and selected.task.flat then
		directory = vim.fs.dirname(selected.task.path)
	elseif selected.task then
		directory = selected.task.cwd
	elseif selected.parts and #selected.parts > 0 then
		directory = vim.fs.joinpath(state.artifacts, unpack(selected.parts))
	end
	if not directory then
		return
	end
	local project_root = require("neoterm.terms.artifacts.cwd").resolve(directory)
	if not project_root then
		return
	end
	require("neoterm.prompts").run(
		require("neoterm.helpers.prompt").create_task(false, directory, project_root),
		"task"
	)
end

local function set_root()
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected or not selected.has_children then
		return
	end
	state.root = vim.fs.joinpath(state.artifacts, unpack(selected.parts))
	render()
end

local function up_root()
	if state.root == state.artifacts then
		return
	end
	state.root = vim.fs.dirname(state.root)
	render()
end

local function cycle_mode()
	local index = assert(vim.fn.index(state.modes, state.mode)) + 2
	state.mode = state.modes[index] or state.modes[1]
	render()
end

local function delete_task_buffers(task)
	local config = require("neoterm.config")
	local task_dir = vim.fs.normalize(task.cwd) .. "/"
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local path = vim.fs.normalize(vim.api.nvim_buf_get_name(bufnr))
		local belongs_to_task = task.flat and task.files[path] or (path ~= "" and vim.startswith(path .. "/", task_dir))
		if belongs_to_task then
			if config.bdelete then
				config.bdelete(bufnr)
			else
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end
	end
end

local function delete_selected()
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected then
		return
	end
	local task = selected_task(selected)
	if not task then
		return
	end
	vim.ui.select({ "Delete", "Cancel" }, {
		prompt = string.format("Delete task %s?", table.concat(task.parts, "/")),
	}, function(choice)
		if choice ~= "Delete" then
			return
		end
		delete_task_buffers(task)
		local target = task.flat and task.path or task.cwd
		local flags = task.flat and nil or "rf"
		assert(vim.fn.delete(target, flags) == 0, "Failed to delete artifact task: " .. target)
		render()
	end)
end

local function filter_panel()
	local panel = state
	local original_cursor = vim.api.nvim_win_get_cursor(panel.win)
	local input = vim.api.nvim_create_buf(false, true)
	local width = vim.api.nvim_win_get_width(panel.win)
	local popup = vim.api.nvim_open_win(input, true, {
		relative = "win",
		win = panel.win,
		row = vim.api.nvim_win_get_height(panel.win) - 1,
		col = 0,
		width = width,
		height = 1,
		style = "minimal",
		border = "single",
	})
	vim.wo[popup].winblend = 0
	vim.bo[input].buftype = "prompt"
	vim.fn.prompt_setprompt(input, "")
	local timer = assert(vim.uv.new_timer())
	local pending = false
	local function apply_filter()
		pending = false
		panel.filter = vim.api.nvim_buf_get_lines(input, -2, -1, false)[1]
		panel.filter_index = 1
		render()
	end
	local function finish(accept)
		timer:stop()
		timer:close()
		if accept and pending then
			apply_filter()
		end
		local selected = panel.rows[panel.filter_index or 1]
		panel.filter = nil
		panel.filter_index = nil
		vim.cmd.stopinsert()
		vim.api.nvim_win_close(popup, true)
		vim.api.nvim_set_current_win(panel.win)
		render()
		if accept and selected then
			for line, row in ipairs(panel.rows) do
				if row.text == selected.text then
					vim.api.nvim_win_set_cursor(panel.win, { line, #(row.text:match("^%s*") or "") })
					open_selected()
					break
				end
			end
		else
			vim.api.nvim_win_set_cursor(panel.win, original_cursor)
		end
	end
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = input,
		callback = function()
			if state ~= panel then
				return
			end
			pending = true
			timer:stop()
			timer:start(100, 0, vim.schedule_wrap(function()
				if state == panel and vim.api.nvim_buf_is_valid(input) then
					apply_filter()
				end
			end))
		end,
	})
	vim.keymap.set({ "n", "i" }, "<Esc>", function()
		finish(false)
	end, { buffer = input })
	vim.keymap.set({ "n", "i" }, "<CR>", function()
		finish(true)
	end, { buffer = input })
	local function move(delta)
		if #panel.rows == 0 then
			return
		end
		panel.filter_index = ((panel.filter_index or 1) - 1 + delta) % #panel.rows + 1
		render()
	end
	vim.keymap.set({ "n", "i" }, "<C-n>", function()
		move(1)
	end, { buffer = input })
	vim.keymap.set({ "n", "i" }, "<C-p>", function()
		move(-1)
	end, { buffer = input })
	panel.filter = ""
	panel.filter_index = 1
	render()
	vim.cmd.startinsert()
end

function M.toggle()
	if state and vim.api.nvim_win_is_valid(state.win) then
		close()
		return
	end
	local config = require("neoterm.config")
	local width = config.panel.width
	local artifacts = config.dirs.artifacts
	local root = default_root(artifacts)
	local modes = vim.tbl_keys(config.tasks.modes)
	table.sort(modes)
	vim.cmd(string.format("topleft %dvsplit", width))
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)
	state = {
		win = win,
		buf = buf,
		rows = {},
		tasks = {},
		mode = config.tasks.default_mode or modes[1],
		modes = modes,
		artifacts = artifacts,
		root = root,
	}
	local panel = state
	local file_win = get_last_file_win()
	state.active_file = file_win and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(file_win)) or nil
	state.unsubscribe = require("neoterm.terms.artifacts.tasks").subscribe(function()
		if state == panel and vim.api.nvim_win_is_valid(panel.win) then
			render()
		end
	end)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "toggleterm-task-panel"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.wo[win].cursorline = true
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].winfixwidth = true
	vim.wo[win].wrap = false
	vim.keymap.set("n", "é", filter_panel, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "c", create_task, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "f", cycle_mode, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "r", set_root, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "u", up_root, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "<cr>", open_selected, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "x", delete_selected, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = events,
		buffer = buf,
		callback = function()
			if state == panel then
				vim.api.nvim_clear_autocmds({ group = events })
				if panel.unsubscribe then
					panel.unsubscribe()
				end
				state = nil
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufEnter", {
		group = events,
		buffer = buf,
		callback = function()
			if state ~= panel then
				return
			end
			local line = active_task_line()
			if line then
				vim.api.nvim_win_set_cursor(win, { line, #(state.rows[line].text:match("^%s*") or "") })
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufEnter", {
		group = events,
		callback = function(args)
			if state ~= panel or args.buf == buf then
				return
			end
			local path = vim.api.nvim_buf_get_name(args.buf)
			if path ~= "" then
				panel.active_file = path
				render()
			end
		end,
	})
	render()
	local line = active_task_line()
	if line then
		vim.api.nvim_win_set_cursor(win, { line, #(state.rows[line].text:match("^%s*") or "") })
	end
end

return M
