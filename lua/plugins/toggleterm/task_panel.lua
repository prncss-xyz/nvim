local M = {}

local get_last_file_win = require("my.windows").get_last_file_win

local state
local namespace = vim.api.nvim_create_namespace("toggleterm-task-panel")

local function close()
	if state and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, false)
	end
	state = nil
end

local function create_rows(tasks, statuses)
	local result = {}
	for _, status in ipairs(statuses) do
		local projects = {}
		for _, task in ipairs(tasks) do
			if task.status == status.name then
				projects[task.project] = projects[task.project] or {}
				table.insert(projects[task.project], task)
			end
		end
		if not vim.tbl_isempty(projects) then
			table.insert(result, { text = "● " .. status.name, status = status.name })
			local names = vim.tbl_keys(projects)
			table.sort(names)
			for _, project in ipairs(names) do
				table.insert(result, { text = "  󰉋 " .. project, status = status.name, project = project })
				table.sort(projects[project], function(a, b)
					return a.branch < b.branch
				end)
				for _, task in ipairs(projects[project]) do
					table.insert(result, {
						text = "    " .. task.branch,
						status = status.name,
						project = project,
						branch = task.branch,
					})
				end
			end
		end
	end
	return result
end

local function render()
	local config = require("plugins.toggleterm.config")
	state.tasks =
		require("plugins.toggleterm.artifact_tasks").scan(require("my.parameters").dirs.artifacts, config.status)
	state.rows = create_rows(state.tasks, config.status)
	local lines = vim.tbl_map(function(row)
		return row.text
	end, state.rows)
	if #lines == 0 then
		lines = { "No artifact tasks" }
	end
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
	for index, row in ipairs(state.rows) do
		vim.api.nvim_buf_set_extmark(state.buf, namespace, index - 1, 0, {
			end_col = #row.text,
			hl_group = row.branch and "NeoTreeFileName" or "NeoTreeDirectoryName",
		})
	end
end

local function selected_task(selected)
	if not selected.branch then
		return
	end
	return vim.iter(state.tasks):find(function(task)
		return task.status == selected.status and task.project == selected.project and task.branch == selected.branch
	end)
end

local function open_selected()
	local selected = state.rows[vim.api.nvim_win_get_cursor(state.win)[1]]
	if not selected then
		return
	end
	local latest = require("plugins.toggleterm.artifact_tasks").latest(state.tasks, function(task)
		return task.status == selected.status
			and (selected.project == nil or task.project == selected.project)
			and (selected.branch == nil or task.branch == selected.branch)
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
	elseif selected.branch then
		local task = assert(selected_task(selected), "Selected artifact task not found")
		vim.api.nvim_win_call(target_win, function()
			require("plugins.toggleterm.config").create(vim.fn.fnameescape(vim.fs.joinpath(task.dir, "index.md")))
		end)
		vim.api.nvim_set_current_win(target_win)
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
		prompt = string.format("Delete task %s/%s?", task.project, task.branch),
	}, function(choice)
		if choice ~= "Delete" then
			return
		end
		assert(vim.fn.delete(task.dir, "rf") == 0, "Failed to delete artifact task: " .. task.dir)
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
	state = { win = win, buf = buf, rows = {}, tasks = {} }
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
	vim.keymap.set("n", "r", render, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "<cr>", open_selected, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "x", delete_selected, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })
	render()
end

return M
