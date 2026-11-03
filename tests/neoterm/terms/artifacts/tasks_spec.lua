local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
				artifacts = vim.fs.joinpath(vim.fn.tempname(), "artifacts")
				folder = vim.fs.joinpath(artifacts, "sample", "scope", "feature")
				vim.fn.mkdir(folder, "p")
				package.loaded["neoterm.config"] = {
					dirs = { projects = vim.fs.joinpath(vim.fs.dirname(artifacts), "projects"), artifacts = artifacts },
					default_branches = { "main" },
				}
				tasks = require("neoterm.terms.artifacts.tasks")
				function write(name, lines)
					local path = vim.fs.joinpath(folder, name)
					vim.fn.mkdir(vim.fs.dirname(path), "p")
					vim.fn.writefile(lines, path)
					return path
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["tasks fork unless their task.md sets fork: false"] = function()
	child.lua([[
		local plan = write("plan.md", { "plan" })
		local prefixed = write("notes/review.plan.md", { "plan" })
		assert(tasks.fork(vim.fs.joinpath(folder, "task.md")) == true)
		assert(tasks.fork(plan) == true)
		for _, case in ipairs({
			{ { "task" }, true },
			{ { "---", "status: ready", "---", "task" }, true },
			{ { "---", "fork: true", "---", "task" }, true },
			{ { "---", "status: ready", "fork: false # local", "---", "task" }, false },
			{ { "---", "fork: false", "---" }, false },
		}) do
			local task = write("task.md", case[1])
			assert(tasks.fork(task) == case[2], vim.inspect(case))
			assert(tasks.fork(plan) == case[2], vim.inspect(case))
			assert(tasks.fork(prefixed) == case[2], vim.inspect(case))
		end
		write("task.md", { "---", "fork: no", "---", "task" })
		assert(not pcall(tasks.fork, plan))
	]])
end

return T
