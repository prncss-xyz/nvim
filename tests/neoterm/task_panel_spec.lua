local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
				root = vim.fn.tempname()
				projects = vim.fs.joinpath(root, "projects")
				artifacts = vim.fs.joinpath(root, "artifacts")
				package.loaded["neoterm.config"] = {
					dirs = { projects = projects, artifacts = artifacts },
					default_branches = { "main" },
					task_panel = {
						width = 30,
						keybindings = { ["."] = "project_root", n = "next_mode", u = "up_root", q = "close" },
					},
					tasks = { default_mode = "focus" },
					open_files_do_not_replace_types = {},
				}
				package.loaded["neoterm.terms.artifacts.statuses"] = {
					modes = function()
						return { all = {}, focus = {} }
					end,
					order = function()
						return {}
					end,
				}
				package.loaded["neoterm.terms.artifacts.tasks"] = {
					precedes = require("neoterm.terms.artifacts.tasks").precedes,
					get = function()
						return {}
					end,
					subscribe = function()
						return function() end
					end,
					fork = function()
						return true
					end,
				}
				function checkout(project, branch)
					local path = vim.fs.joinpath(projects, project, branch)
					vim.fn.mkdir(path, "p")
					vim.fn.system({ "git", "init", "-b", branch, path })
					assert(vim.v.shell_error == 0)
					return path
				end
				function panel_root()
					require("neoterm.task_panel").toggle()
					return panel_header():match("^(.-) %[")
				end
				function panel_header()
					return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
				end
				function press(key)
					assert(vim.fn.maparg(key, "n", false, true).callback)()
				end
			]])
		end,
		post_case = function()
			child.lua([[vim.fn.delete(root, "rf")]])
		end,
		post_once = child.stop,
	},
})

T["orders tasks like the auto panel and counts tasks without directory rows"] = function()
	child.lua([[
		vim.cmd.cd(checkout("sample", "main"))
		local tasks = {}
		for _, path in ipairs({ "10-last", "2-first", "z", "a", "a/10-ten", "a/2-two", "a/x" }) do
			table.insert(tasks, {
				parts = vim.split("sample/" .. path, "/"),
				cwd = vim.fs.joinpath(artifacts, "sample", path),
				status = "ready",
				logical_status = "ready",
			})
		end
		require("neoterm.terms.artifacts.tasks").get = function() return tasks end
		require("neoterm.terms.artifacts.statuses").modes = function()
			return { focus = { "ready" } }
		end
		require("neoterm.terms.artifacts.statuses").order = function()
			return { ready = 1 }
		end
		require("neoterm.task_panel").toggle()
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		assert(vim.deep_equal(lines, {
			"sample [focus]",
			"ready:",
			"󰉋 a",
			"  󰉋 x",
			"  󰉋 2-two",
			"  󰉋 10-ten",
			"󰉋 a",
			"󰉋 z",
			"󰉋 2-first",
			"󰉋 10-last",
			"count: 7",
		}), vim.inspect(lines))
	]])
end

T["opens on the project of the current working directory"] = function()
	child.lua([[
		vim.fn.mkdir(vim.fs.joinpath(artifacts, "utils-mono"), "p")
		vim.cmd.cd(checkout("utils-mono", "main"))
		assert(panel_root() == "utils-mono")
	]])
end

T["opens on the project of the current artifact file"] = function()
	child.lua([[
		checkout("utils-mono", "main")
		vim.cmd.cd(checkout("other", "main"))
		local file = vim.fs.joinpath(artifacts, "utils-mono", "fix-store", "task.md")
		vim.fn.mkdir(vim.fs.dirname(file), "p")
		vim.fn.writefile({ "task" }, file)
		vim.cmd.edit(file)
		assert(panel_root() == "utils-mono")
	]])
end

T["opens on all artifacts for an artifact file without a checkout"] = function()
	child.lua([[
		local file = vim.fs.joinpath(artifacts, "orphan", "fix-store", "task.md")
		vim.fn.mkdir(vim.fs.dirname(file), "p")
		vim.fn.writefile({ "task" }, file)
		vim.cmd.edit(file)
		assert(panel_root() == ".")
	]])
end

T["dot roots the last regular file's project independently of cwd"] = function()
	child.lua([[
		local project = checkout("utils-mono", "main")
		vim.cmd.cd(checkout("other", "main"))
		vim.cmd.edit(vim.fs.joinpath(project, "source.lua"))
		assert(panel_root() == "other")
		press(".")
		assert(panel_header() == "utils-mono [focus]")
		press("n")
		press("q")
		require("neoterm.task_panel").toggle()
		assert(panel_header() == "utils-mono [all]")
	]])
end

T["dot uses the latest regular file and ignores named special buffers"] = function()
	child.lua([[
		vim.cmd.cd(checkout("other", "main"))
		local project = checkout("utils-mono", "main")
		vim.cmd.edit(vim.fs.joinpath(projects, "other", "main", "first.lua"))
		local file_win = vim.api.nvim_get_current_win()
		panel_root()
		local panel_win = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(file_win)
		vim.cmd.edit(vim.fs.joinpath(project, "source.lua"))
		local special = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(special, vim.fs.joinpath(projects, "other", "special"))
		vim.api.nvim_win_set_buf(file_win, special)
		vim.api.nvim_set_current_win(panel_win)
		press(".")
		assert(panel_header() == "utils-mono [focus]")
	]])
end

T["dot roots an artifact file's project without a checkout"] = function()
	child.lua([[
		local file = vim.fs.joinpath(artifacts, "orphan", "fix-store", "task.md")
		vim.fn.mkdir(vim.fs.dirname(file), "p")
		vim.fn.writefile({ "task" }, file)
		vim.cmd.edit(file)
		assert(panel_root() == ".")
		press(".")
		assert(panel_header() == "orphan [focus]")
	]])
end

T["dot leaves the root unchanged without a project file"] = function()
	child.lua([[
		vim.cmd.cd(checkout("utils-mono", "main"))
		panel_root()
		press(".")
		assert(panel_header() == "utils-mono [focus]")
		local panel_win = vim.api.nvim_get_current_win()
		vim.cmd.wincmd("p")
		vim.cmd.edit(vim.fs.joinpath(root, "unrelated.md"))
		vim.api.nvim_set_current_win(panel_win)
		press(".")
		assert(panel_header() == "utils-mono [focus]")
	]])
end

for _, action in ipairs({ "toggle", "binding", "window", "buffer" }) do
	T["remembers initial mode and root after closing via " .. action] = function()
		child.lua(
			[[
			local action = ...
			vim.fn.mkdir(vim.fs.joinpath(artifacts, "utils-mono"), "p")
			vim.cmd.cd(checkout("utils-mono", "main"))
			assert(panel_root() == "utils-mono")
			local close = {
				toggle = function() require("neoterm.task_panel").toggle() end,
				binding = function() press("q") end,
				window = function() vim.api.nvim_win_close(0, false) end,
				buffer = function() vim.api.nvim_buf_delete(0, { force = true }) end,
			}
			close[action]()
			vim.cmd.cd(checkout("other", "main"))
			require("neoterm.config").tasks.default_mode = "all"
			require("neoterm.task_panel").toggle()
			assert(panel_header() == "utils-mono [focus]")
		]],
			{ action }
		)
	end
end

return T
