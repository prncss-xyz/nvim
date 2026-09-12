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
		vim.fn.writefile({ "ready" }, vim.fs.joinpath(task, "design.md"))
		vim.fn.writefile({ "---", "status: done", "---" }, vim.fs.joinpath(task, "index.md"))
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
		local one = vim.fs.joinpath(root, "nvim", "one")
		local two = vim.fs.joinpath(root, "nvim", "two")
		vim.fn.mkdir(one, "p")
		vim.fn.mkdir(two, "p")
		local first = vim.fs.joinpath(one, "index.md")
		local latest = vim.fs.joinpath(two, "index.md")
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
		vim.api.nvim_win_set_cursor(0, { 4, 0 })
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
		lines = { "● draft", "  󰉋 nvim", "    one", "    two" },
		opened = child.lua_get("expected"),
		focused_file_win = true,
		panel_unchanged = true,
		filetype = "toggleterm-task-panel",
	}, child.lua_get("result"))
end

T["opens an unloaded artifact instead of creating index.md"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local task = vim.fs.joinpath(root, "nvim", "has-artifact")
		vim.fn.mkdir(task, "p")
		local artifact = vim.fs.joinpath(task, "design.md")
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

T["creates index.md for an empty task directory"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local task = vim.fs.joinpath(root, "nvim", "empty")
		vim.fn.mkdir(task, "p")
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
		expected = vim.fs.joinpath(task, "index.md")
	]])

	assert.same({
		created = child.lua_get("expected"),
		opened = child.lua_get("expected"),
		focused_file_win = true,
	}, child.lua_get("result"))
end

T["prompts before deleting a task"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local task = vim.fs.joinpath(root, "nvim", "remove-me")
		vim.fn.mkdir(task, "p")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(task, "index.md"))
		package.loaded["my.parameters"] = { dirs = { artifacts = root } }
		package.loaded["plugins.toggleterm.config"] = {
			panel = { width = 24 },
			status = { { name = "draft" } },
		}
		local prompt
		vim.ui.select = function(items, opts, callback)
			prompt = opts.prompt
			callback(items[1])
		end
		require("plugins.toggleterm.task_panel").toggle()
		vim.api.nvim_win_set_cursor(0, { 3, 0 })
		vim.api.nvim_feedkeys("x", "x", false)
		result = {
			prompt = prompt,
			deleted = vim.fn.isdirectory(task) == 0,
			lines = vim.api.nvim_buf_get_lines(0, 0, -1, false),
		}
	]])

	assert.same({
		prompt = "Delete task nvim/remove-me?",
		deleted = true,
		lines = { "No artifact tasks" },
	}, child.lua_get("result"))
end

return T
