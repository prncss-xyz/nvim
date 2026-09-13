local M = {}

local get_last_file_win = require("my.windows").get_last_file_win

local state
local namespace = vim.api.nvim_create_namespace("toggleterm-task-panel")

local function stop_watchers(panel)
	for _, watcher in ipairs(panel.watchers or {}) do
		watcher:stop()
		if not watcher:is_closing() then
			watcher:close()
		end
	end
	panel.watchers = {}
end

local function stop_refresh_timer(panel)
	if panel.refresh_timer then
		panel.refresh_timer:stop()
		if not panel.refresh_timer:is_closing() then
			panel.refresh_timer:close()
		end
		panel.refresh_timer = nil
	end
end

local function close()
	if state then
		stop_watchers(state)
		stop_refresh_timer(state)
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
			table.insert(result, { text = status.name .. ":", status = status.name, parts = {} })
			local function append(node, depth, parts)
				local names = vim.tbl_keys(node.children)
				table.sort(names)
				for _, name in ipairs(names) do
					local child = node.children[name]
					local child_parts = vim.deepcopy(parts)
					table.insert(child_parts, name)
					local icon = child.task and child.task.flat and "󰈙" or "󰉋"
					table.insert(result, {
						text = string.rep("  ", depth + 1) .. icon .. " " .. name,
						status = status.name,
						parts = child_parts,
						has_children = not vim.tbl_isempty(child.children),
						dir = child.task and child.task.dir or nil,
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
	local config = require("plugins.toggleterm.config")
	state.tasks =
		require("plugins.toggleterm.artifact_tasks").scan(require("my.parameters").dirs.artifacts, config.status)
	local relative_root = assert(vim.fs.relpath(state.artifacts, state.root))
	local root_parts = relative_root == "." and {} or vim.split(relative_root, "/", { plain = true })
	state.rows = create_rows(state.tasks, config.status, root_parts)
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
			hl_group = row.root and "Comment" or (row.task and "DiagnosticInfo" or "NeoTreeDirectoryName"),
		})
	end
end

local function start_watchers(panel)
	stop_watchers(panel)
	local recursive = vim.fn.has("macunix") == 1 or vim.fn.has("win32") == 1

	local function changed()
		if state ~= panel or not panel.refresh_timer then
			return
		end
		panel.refresh_timer:stop()
		panel.refresh_timer:start(100, 0, vim.schedule_wrap(function()
			if state ~= panel or not vim.api.nvim_win_is_valid(panel.win) then
				return
			end
			render()
			start_watchers(panel)
		end))
	end

	local function watch(dir)
		local watcher = assert(vim.uv.new_fs_event())
		local ok = watcher:start(dir, { recursive = recursive }, changed)
		if not ok then
			watcher:close()
			return
		end
		table.insert(panel.watchers, watcher)

		if not recursive then
			for name, kind in vim.fs.dir(dir) do
				if kind == "directory" and not vim.startswith(name, ".") then
					watch(vim.fs.joinpath(dir, name))
				end
			end
		end
	end

	watch(panel.artifacts)
end

local function selected_task(selected)
	return selected.task
end

local function open_selected()
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected then
		return
	end
	local latest = require("plugins.toggleterm.artifact_tasks").latest(state.tasks, function(task)
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
				require("plugins.toggleterm.config").create(vim.fn.fnameescape(latest.path))
			end)
		end
		vim.api.nvim_set_current_win(target_win)
	elseif selected.task then
		local task = assert(selected_task(selected), "Selected artifact task not found")
		vim.api.nvim_win_call(target_win, function()
			require("plugins.toggleterm.config").create(vim.fn.fnameescape(vim.fs.joinpath(task.dir, "index.md")))
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
		directory = selected.task.dir
	elseif selected.parts and #selected.parts > 0 then
		directory = vim.fs.joinpath(state.artifacts, unpack(selected.parts))
	end
	if not directory then
		return
	end
	local project_root = require("plugins.toggleterm.terms.artifact_cwd").resolve(directory)
	if not project_root then
		return
	end
	require("plugins.toggleterm.prompts").run(
		require("plugins.toggleterm.prompt_utils").create_task(false, directory, project_root),
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

local function delete_task_buffers(task)
	local config = require("plugins.toggleterm.config")
	local task_dir = vim.fs.normalize(task.dir) .. "/"
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
		local target = task.flat and task.path or task.dir
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
	local width = require("plugins.toggleterm.config").panel.width
	vim.cmd(string.format("topleft %dvsplit", width))
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)
	local artifacts = require("my.parameters").dirs.artifacts
	state = {
		win = win,
		buf = buf,
		rows = {},
		tasks = {},
		watchers = {},
		refresh_timer = assert(vim.uv.new_timer()),
		artifacts = artifacts,
		root = artifacts,
	}
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
	vim.keymap.set("n", "r", set_root, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "u", up_root, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "<cr>", open_selected, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "x", delete_selected, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })
	render()
	start_watchers(state)
end

return M
