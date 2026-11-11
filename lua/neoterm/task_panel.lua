local M = {}
local panel_utils = require("neoterm.helpers.panel")

local get_last_file_win = require("neoterm.helpers.win_history").get_last_file_win

local state
local last_mode
local last_root
local namespace = vim.api.nvim_create_namespace("toggleterm-task-panel")
local events = vim.api.nvim_create_augroup("toggleterm-task-panel-focus", { clear = true })

local function default_root(artifacts)
	local artifact_cwd = require("neoterm.terms.artifacts.cwd")
	local dir = artifact_cwd.context_dir()
	if not dir and artifact_cwd.contains(vim.api.nvim_buf_get_name(0)) then
		return artifacts
	end
	dir = dir or vim.fn.getcwd()

	local projects = require("neoterm.config").dirs.projects
	local relative = vim.fs.relpath(projects, vim.fs.abspath(dir))
	if relative == nil or relative == "." then
		return artifacts
	end
	return artifact_cwd.for_project(dir)
end

local function clear()
	vim.api.nvim_clear_autocmds({ group = events })
	if state then
		last_mode, last_root = state.mode, state.root
		if state.unsubscribe then
			state.unsubscribe()
		end
	end
	state = nil
end

local function close()
	local panel = state
	clear()
	if panel and vim.api.nvim_win_is_valid(panel.win) then
		vim.api.nvim_win_close(panel.win, false)
	end
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

local function logical_status(task, status_names)
	return vim.startswith(task.logical_status, "ERROR:") and task.logical_status
		or unknown_status(task.status, status_names) and "ERROR:UNKNOWN TAG"
		or task.logical_status
end

local function create_rows(tasks, statuses, status_names, root_parts)
	local result = {}
	local mode_statuses = {}
	for _, status in ipairs(statuses) do
		mode_statuses[status] = true
	end
	local error_groups = { { name = "ERROR:UNKNOWN TAG", broken = true } }
	local seen_errors = { ["ERROR:UNKNOWN TAG"] = true }
	for _, task in ipairs(tasks) do
		local status = logical_status(task, status_names)
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
			local matches = logical_status(task, status_names) == group.name
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
				table.sort(names, function(left, right)
					return require("neoterm.terms.artifacts.tasks").precedes({ left }, { right })
				end)
				for _, name in ipairs(names) do
					local child = node.children[name]
					local child_parts = vim.deepcopy(parts)
					table.insert(child_parts, name)
					local has_children = not vim.tbl_isempty(child.children)
					local function append_row(task)
						local icon = task and task.flat and "󰈙" or "󰉋"
						table.insert(result, {
							text = string.rep("  ", depth) .. icon .. " " .. name,
							status = group.name,
							broken = group.broken,
							parts = child_parts,
							has_children = has_children,
							cwd = task and task.cwd or nil,
							task = task,
						})
					end
					if has_children then
						append_row(nil)
						append(child, depth + 1, child_parts)
					end
					if child.task then
						append_row(child.task)
					end
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
	state.tasks = require("neoterm.terms.artifacts.tasks").get()
	local relative_root = assert(vim.fs.relpath(state.artifacts, state.root))
	local root_parts = relative_root == "." and {} or vim.split(relative_root, "/", { plain = true })
	local statuses = assert(state.mode_statuses[state.mode], "Unknown task panel mode: " .. state.mode)
	state.status_names = require("neoterm.terms.artifacts.statuses").order()
	state.rows = create_rows(state.tasks, statuses, state.status_names, root_parts)
	table.insert(state.rows, 1, { text = string.format("%s [%s]", relative_root, state.mode), root = true })
	if #state.rows == 1 then
		table.insert(state.rows, { text = "No artifact tasks" })
	end
	state.rows = panel_utils.filter_rows(state.rows, state.filter)
	local count = #vim.tbl_filter(function(row)
		return row.task ~= nil
	end, state.rows)
	table.insert(state.rows, { text = "count: " .. count, footer = true })
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
			hl_group = (row.root or row.footer) and "Comment"
				or (row.status_heading and "DiagnosticWarn")
				or (row.task and "DiagnosticInfo")
				or "NeoTreeDirectoryName",
		})
	end
	if not panel_utils.highlight_filter(state, namespace) then
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
		return require("neoterm.terms.artifacts.tasks").precedes(left.parts, right.parts)
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
		if logical_status(task, state.status_names) ~= selected.status then
			return false
		end
		for index, part in ipairs(selected.parts) do
			if task.parts[index] ~= part then
				return false
			end
		end
		return true
	end)
	local file_windows = require("neoterm.helpers.file_windows")
	if latest then
		file_windows.open(latest.path, latest.bufnr)
	elseif selected.task then
		local task = assert(selected_task(selected), "Selected artifact task not found")
		file_windows.open(vim.fs.joinpath(task.cwd, "index.md"))
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

local function project_root()
	local path = state.active_file
	if not path or path == "" then
		return
	end
	local paths = require("neoterm.terms.artifacts.paths")
	local project = paths.artifact_project(path)
	if not project then
		local relative = vim.fs.relpath(require("neoterm.config").dirs.projects, path)
		if relative == nil or relative == "." then
			return
		end
		project = paths.project(path)
	end
	state.root = paths.project_artifacts(project)
	render()
end

local function up_root()
	if state.root == state.artifacts then
		return
	end
	state.root = vim.fs.dirname(state.root)
	render()
end

local function change_mode(delta)
	local index = vim.fn.index(state.modes, state.mode)
	assert(index >= 0, "Unknown task panel mode: " .. state.mode)
	state.mode = state.modes[(index + delta) % #state.modes + 1]
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
	require("neoterm.helpers.confirm")(string.format("Delete task %s?", table.concat(task.parts, "/")), function(confirmed)
		if not confirmed then
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
	panel_utils.open_filter(panel, {
		render = render,
		valid = function()
			return state == panel
		end,
		same = function(row, selected)
			return row.text == selected.text and row.status == selected.status
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
	local width = config.task_panel.width
	local artifacts = config.dirs.artifacts
	local root = last_root and vim.fs.relpath(artifacts, last_root) and last_root or default_root(artifacts)
	local mode_statuses = require("neoterm.terms.artifacts.statuses").modes()
	local modes = vim.tbl_keys(mode_statuses)
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
		mode = (last_mode and mode_statuses[last_mode] and last_mode) or config.tasks.default_mode or modes[1],
		modes = modes,
		mode_statuses = mode_statuses,
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
	local operations = {
		filter = filter_panel,
		create = create_task,
		next_mode = function()
			change_mode(1)
		end,
		previous_mode = function()
			change_mode(-1)
		end,
		set_root = set_root,
		project_root = project_root,
		up_root = up_root,
		open = open_selected,
		delete = delete_selected,
		close = close,
	}
	panel_utils.bind(panel, config.task_panel.keybindings, operations)
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = events,
		buffer = buf,
		callback = function()
			if state == panel then
				clear()
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
			if vim.bo[args.buf].buftype == "" and path ~= "" then
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
