local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua(
				[[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path]]
			)
		end,
		post_once = child.stop,
	},
})

T["derives task status in precedence order"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local task = vim.fs.joinpath(root, "nvim", "feature")
		vim.fn.mkdir(task, "p")
		vim.fn.writefile({ "---", "status: done", "---" }, vim.fs.joinpath(task, "task.md"))
		vim.fn.writefile({ "ready" }, vim.fs.joinpath(task, "design.md"))
		local statuses = {
			{ name = "draft" },
			{ name = "ready", files = { "design.md" } },
			{ name = "done" },
		}
		result = require("plugins.toggleterm.artifact_tasks").scan(root, statuses)
	]])

	local result = child.lua_get("result")
	assert.same(1, #result)
	assert.same("done", result[1].status)
	assert.same("nvim", result[1].project)
	assert.same("feature", result[1].branch)
end

T["renders status project branch and opens the latest matching artifact"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		expected_root = root
		local one = vim.fs.joinpath(root, "nvim", "one")
		local two = vim.fs.joinpath(root, "nvim", "two")
		vim.fn.mkdir(one, "p")
		vim.fn.mkdir(two, "p")
		local first = vim.fs.joinpath(one, "index.md")
		local latest = vim.fs.joinpath(two, "index.md")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(one, "task.md"))
		vim.fn.writefile({ "task" }, vim.fs.joinpath(two, "task.md"))
		vim.fn.writefile({ "one" }, first)
		vim.fn.writefile({ "two" }, latest)
		vim.cmd.edit(vim.fn.fnameescape(first))
		vim.cmd.edit(vim.fn.fnameescape(latest))
		vim.cmd.enew()
		local file_win = vim.api.nvim_get_current_win()
		expected = latest
		package.loaded["my.parameters"] = { dirs = { artifacts = root } }
		package.loaded["plugins.toggleterm.config"] = {
			panel = { width = 24 },
			status = { { name = "draft" } },
		}
		require("plugins.toggleterm.task_panel").toggle()
		local panel_win = vim.api.nvim_get_current_win()
		local buf = vim.api.nvim_get_current_buf()
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local filetype = vim.bo[buf].filetype
		vim.api.nvim_win_set_cursor(0, { 5, 0 })
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		result = {
			lines = lines,
			opened = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(file_win)),
			focused_file_win = vim.api.nvim_get_current_win() == file_win,
			panel_unchanged = vim.api.nvim_win_get_buf(panel_win) == buf,
			filetype = filetype,
		}
	]])

	assert.same({
		lines = { ".", "● draft", "  󰉋 nvim", "    󰉋 one", "    󰉋 two" },
		opened = child.lua_get("expected"),
		focused_file_win = true,
		panel_unchanged = true,
		filetype = "toggleterm-task-panel",
	}, child.lua_get("result"))
end

T["highlights only directories that immediately contain task.md"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		expected_root = root
		local parent = vim.fs.joinpath(root, "project", "parent")
		local child_task = vim.fs.joinpath(parent, "group", "child")
		vim.fn.mkdir(child_task, "p")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(parent, "task.md"))
		vim.fn.writefile({ "task" }, vim.fs.joinpath(child_task, "task.md"))
		vim.fn.mkdir(vim.fs.joinpath(root, ".hidden"), "p")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(root, ".hidden", "task.md"))
		package.loaded["my.parameters"] = { dirs = { artifacts = root } }
		package.loaded["plugins.toggleterm.config"] = {
			panel = { width = 24 },
			status = { { name = "draft" } },
		}
		require("plugins.toggleterm.task_panel").toggle()
		local marks = vim.api.nvim_buf_get_extmarks(vim.api.nvim_get_current_buf(), -1, 0, -1, { details = true })
		result = {
			lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
			highlights = vim.tbl_map(function(mark)
				return mark[4].hl_group
			end, marks),
		}
	]])

	assert.same({
		lines = {
			".",
			"● draft",
			"  󰉋 project",
			"    󰉋 parent",
			"      󰉋 group",
			"        󰉋 child",
		},
		highlights = {
			"Comment",
			"NeoTreeDirectoryName",
			"NeoTreeDirectoryName",
			"DiagnosticInfo",
			"NeoTreeDirectoryName",
			"DiagnosticInfo",
		},
	}, child.lua_get("result"))
end

T["sets and raises the displayed root path"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local task = vim.fs.joinpath(root, "project", "group", "task")
		local outside = vim.fs.joinpath(root, "outside", "task")
		vim.fn.mkdir(task, "p")
		vim.fn.mkdir(outside, "p")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(task, "task.md"))
		vim.fn.writefile({ "task" }, vim.fs.joinpath(outside, "task.md"))
		vim.fn.writefile({ "ready" }, vim.fs.joinpath(outside, "design.md"))
		package.loaded["my.parameters"] = { dirs = { artifacts = root } }
		package.loaded["plugins.toggleterm.config"] = {
			panel = { width = 24 },
			status = { { name = "draft" }, { name = "ready", files = { "design.md" } } },
		}
		require("plugins.toggleterm.task_panel").toggle()
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		vim.api.nvim_feedkeys("r", "x", false)
		local rooted = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		vim.api.nvim_feedkeys("u", "x", false)
		local raised = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
		vim.api.nvim_feedkeys("u", "x", false)
		result = {
			rooted = rooted,
			raised = raised,
			bounded = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1],
		}
		expected = {
			rooted = { "project", "● draft", "  󰉋 group", "    󰉋 task" },
			raised = ".",
			bounded = ".",
		}
	]])

	assert.same(child.lua_get("expected"), child.lua_get("result"))
end

T["opens an unloaded artifact instead of creating index.md"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local task = vim.fs.joinpath(root, "nvim", "has-artifact")
		vim.fn.mkdir(task, "p")
		local artifact = vim.fs.joinpath(task, "design.md")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(task, "task.md"))
		vim.fn.writefile({ "design" }, artifact)
		vim.cmd.enew()
		local file_win = vim.api.nvim_get_current_win()
		local created
		package.loaded["my.parameters"] = { dirs = { artifacts = root } }
		package.loaded["plugins.toggleterm.config"] = {
			panel = { width = 24 },
			status = { { name = "draft" } },
			create = function(path)
				created = path
				vim.cmd.edit(path)
			end,
		}
		require("plugins.toggleterm.task_panel").toggle()
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		result = {
			created = created,
			opened = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(file_win)),
		}
		expected = artifact
	]])

	assert.same({
		created = child.lua_get("expected"),
		opened = child.lua_get("expected"),
	}, child.lua_get("result"))
end

T["opens task.md for a task with no other artifacts"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local task = vim.fs.joinpath(root, "nvim", "empty")
		vim.fn.mkdir(task, "p")
		local marker = vim.fs.joinpath(task, "task.md")
		vim.fn.writefile({ "task" }, marker)
		vim.cmd.enew()
		local file_win = vim.api.nvim_get_current_win()
		local created
		package.loaded["my.parameters"] = { dirs = { artifacts = root } }
		package.loaded["plugins.toggleterm.config"] = {
			panel = { width = 24 },
			status = { { name = "draft" } },
			create = function(path)
				created = path
				vim.cmd.edit(path)
			end,
		}
		require("plugins.toggleterm.task_panel").toggle()
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		result = {
			created = created,
			opened = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(file_win)),
			focused_file_win = vim.api.nvim_get_current_win() == file_win,
		}
		expected = marker
	]])

	assert.same({
		created = child.lua_get("expected"),
		opened = child.lua_get("expected"),
		focused_file_win = true,
	}, child.lua_get("result"))
end

T["prompts before deleting a task and deletes its buffers through config"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		expected_root = root
		local task = vim.fs.joinpath(root, "nvim", "remove-me")
		vim.fn.mkdir(task, "p")
		local index = vim.fs.joinpath(task, "index.md")
		local design = vim.fs.joinpath(task, "design.md")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(task, "task.md"))
		vim.fn.writefile({ "task" }, index)
		vim.fn.writefile({ "design" }, design)
		vim.cmd.edit(vim.fn.fnameescape(index))
		local index_buf = vim.api.nvim_get_current_buf()
		vim.cmd.edit(vim.fn.fnameescape(design))
		local design_buf = vim.api.nvim_get_current_buf()
		vim.cmd.enew()
		local deleted_buffers = {}
		package.loaded["my.parameters"] = { dirs = { artifacts = root } }
		package.loaded["plugins.toggleterm.config"] = {
			panel = { width = 24 },
			status = { { name = "draft" } },
			bdelete = function(bufnr)
				table.insert(deleted_buffers, vim.api.nvim_buf_get_name(bufnr))
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end,
		}
		local prompt
		vim.ui.select = function(items, opts, callback)
			prompt = opts.prompt
			callback(items[1])
		end
		require("plugins.toggleterm.task_panel").toggle()
		vim.api.nvim_win_set_cursor(0, { 4, 0 })
		vim.api.nvim_feedkeys("x", "x", false)
		table.sort(deleted_buffers)
		result = {
			prompt = prompt,
			deleted = vim.fn.isdirectory(task) == 0,
			deleted_buffers = deleted_buffers,
			buffers_valid = vim.api.nvim_buf_is_valid(index_buf) or vim.api.nvim_buf_is_valid(design_buf),
			lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
		}
		expected_buffers = { design, index }
		table.sort(expected_buffers)
	]])

	assert.same({
		prompt = "Delete task nvim/remove-me?",
		deleted = true,
		deleted_buffers = child.lua_get("expected_buffers"),
		buffers_valid = false,
		lines = { ".", "No artifact tasks" },
	}, child.lua_get("result"))
end

return T
