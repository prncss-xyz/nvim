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
					task_panel = { width = 30, keybindings = {} },
					tasks = { default_mode = "focus" },
				}
				package.loaded["neoterm.helpers.win_history"] = { get_last_file_win = function() end }
				package.loaded["neoterm.terms.artifacts.statuses"] = {
					modes = function()
						return { focus = {} }
					end,
					order = function()
						return {}
					end,
				}
				package.loaded["neoterm.terms.artifacts.tasks"] = {
					get = function()
						return {}
					end,
					subscribe = function()
						return function() end
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
					local header = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
					return header:match("^(.-) %[")
				end
			]])
		end,
		post_case = function()
			child.lua([[vim.fn.delete(root, "rf")]])
		end,
		post_once = child.stop,
	},
})

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

return T
