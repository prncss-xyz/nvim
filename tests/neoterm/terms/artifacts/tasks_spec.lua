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
					tasks = { default_status = "ready", status = { { name = "ready" } } },
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

T["project index retains scanned branches and identifies linked checkouts"] = function()
	child.lua([[
		local root = package.loaded["neoterm.config"].dirs.projects
		local main = root .. "/sample/main"
		local linked = root .. "/sample/feature space"
		local relative = root .. "/sample/relative"
		vim.fn.mkdir(main .. "/.git/worktrees/feature", "p")
		vim.fn.mkdir(main .. "/.git/worktrees/relative", "p")
		vim.fn.mkdir(linked, "p")
		vim.fn.mkdir(relative, "p")
		vim.fn.mkdir(root .. "/plain/.git", "p")
		vim.fn.mkdir(root .. "/sample/non-git", "p")
		vim.fn.writefile({ "gitdir: " .. main .. "/.git/worktrees/feature" }, linked .. "/.git")
		vim.fn.writefile({ "gitdir: ../main/.git/worktrees/relative" }, relative .. "/.git")
		vim.fn.writefile({ "../.." }, main .. "/.git/worktrees/feature/commondir")
		vim.fn.writefile({ "../.." }, main .. "/.git/worktrees/relative/commondir")
		assert(tasks.projects() == nil)
		assert(vim.wait(3000, function() return tasks.projects() ~= nil end, 20))
		assert(tasks.projects().branches.sample["non-git"])
		local expected = {
			{ path = root .. "/plain", git_dir = root .. "/plain/.git" },
			{ path = linked, git_dir = main .. "/.git" },
			{ path = main, git_dir = main .. "/.git" },
			{ path = relative, git_dir = main .. "/.git" },
		}
		assert(vim.deep_equal(tasks.projects().checkouts, expected), vim.inspect(tasks.projects()))
	]])
end

T["project index follows checkout and git marker creation and deletion"] = function()
	child.lua([[
		local root = package.loaded["neoterm.config"].dirs.projects
		local checkout = root .. "/sample/main"
		vim.fn.mkdir(checkout, "p")
		assert(vim.wait(3000, function() return tasks.projects() ~= nil end, 20))
		assert(#tasks.projects().checkouts == 0)
		vim.fn.mkdir(checkout .. "/.git", "p")
		assert(vim.wait(3000, function() return #tasks.projects().checkouts == 1 end, 20))
		vim.fn.delete(checkout .. "/.git", "rf")
		assert(vim.wait(3000, function() return #tasks.projects().checkouts == 0 end, 20))
		vim.fn.mkdir(root .. "/new/main/.git", "p")
		assert(vim.wait(3000, function()
			return tasks.projects().checkouts[1] and tasks.projects().checkouts[1].path == root .. "/new/main"
		end, 20))
		vim.fn.delete(root .. "/new", "rf")
		assert(vim.wait(3000, function() return #tasks.projects().checkouts == 0 end, 20))
	]])
end

return T
