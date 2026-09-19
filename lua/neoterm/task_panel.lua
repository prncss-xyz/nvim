local M = {}

local get_last_file_win = require("neoterm.helpers.win_history").get_last_file_win

local state
local namespace = vim.api.nvim_create_namespace("toggleterm-task-panel")

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

local function create_rows(tasks, statuses, root_parts)
	local result = {}
	for _, status in ipairs(statuses) do
		local root = { children = {} }
		for _, task in ipairs(tasks) do
			if task.status == status.name and #task.parts > #root_parts and has_prefix(task.parts, root_parts) then
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
				text = status.name .. ":",
				status = status.name,
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
						status = status.name,
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

local function render()
	local config = require("neoterm.config")
	state.tasks = require("neoterm.artifact_tasks").get()
	local relative_root = assert(vim.fs.relpath(state.artifacts, state.root))
	local root_parts = relative_root == "." and {} or vim.split(relative_root, "/", { plain = true })
	local statuses = config.status
	if state.focus_mode and vim.iter(statuses):any(function(status)
		return status.focus
	end) then
		statuses = vim.tbl_filter(function(status)
			return status.focus
		end, statuses)
	end
	state.rows = create_rows(state.tasks, statuses, root_parts)
	table.insert(state.rows, 1, { text = relative_root, root = true })
	if #state.rows == 1 then
		table.insert(state.rows, { text = "No artifact tasks" })
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
end

local function selected_task(selected)
	return selected.task
end

local function open_selected()
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected then
		return
	end
	local latest = require("neoterm.artifact_tasks").latest(state.tasks, function(task)
		if task.status ~= selected.status then
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
	local project_root = require("neoterm.terms.artifact_cwd").resolve(directory)
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

local function toggle_focus_mode()
	state.focus_mode = not state.focus_mode
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

function M.toggle()
	if state and vim.api.nvim_win_is_valid(state.win) then
		close()
		return
	end
	local config = require("neoterm.config")
	local width = config.panel.width
	local artifacts = config.dirs.artifacts
	local root = default_root(artifacts)
	vim.cmd(string.format("topleft %dvsplit", width))
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)
	state = {
		win = win,
		buf = buf,
		rows = {},
		tasks = {},
		focus_mode = true,
		artifacts = artifacts,
		root = root,
	}
	local panel = state
	state.unsubscribe = require("neoterm.artifact_tasks").subscribe(function()
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
	vim.keymap.set("n", "c", create_task, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "f", toggle_focus_mode, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "r", set_root, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "u", up_root, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "<cr>", open_selected, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "x", delete_selected, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })
	render()
end

return M
