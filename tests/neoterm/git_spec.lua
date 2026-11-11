local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
				local root = vim.fn.tempname()
				projects = vim.fs.joinpath(root, "projects")
				artifacts = vim.fs.joinpath(root, "artifacts")
				vim.fn.mkdir(vim.fs.joinpath(artifacts, "sample"), "p")
				package.loaded["neoterm.config"] = {
					dirs = { projects = projects, artifacts = artifacts },
					default_branches = { "main", "master" },
				}
				calls, upstream = {}, nil
				notifications = {}
				vim.notify = function(message) table.insert(notifications, message) end
				local system = vim.system
				vim.system = function(command, opts, callback)
					if command[1] ~= "gh" and command[1] ~= "git" then
						return system(command, opts, callback)
					end
					table.insert(calls, table.concat(command, " "))
					local code, stdout = 0, ""
					if command[1] == "gh" and command[3] == "view" then
						code, stdout = upstream and 0 or 1, upstream or ""
					elseif command[1] == "gh" and command[3] == "clone" then
						vim.fn.mkdir(command[5], "p")
					end
					callback({ code = code, stdout = stdout, stderr = "" })
				end
				git = require("neoterm.git")
				function ensure(project)
					local done, result = false, nil
					git.ensure_project(project, function(checkout)
						done, result = true, checkout
					end)
					assert(vim.wait(1000, function() return done end))
					return result
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["an existing default checkout is used without calling gh"] = function()
	child.lua([[
		local checkout = vim.fs.joinpath(projects, "sample", "master")
		vim.fn.mkdir(checkout, "p")
		assert(ensure("sample") == checkout)
		assert(#calls == 0)
	]])
end

T["an existing upstream is cloned into its default branch directory"] = function()
	child.lua([[
		upstream = "develop\n"
		vim.fn.writefile({ "---", "github: someone/sample-repo", "---" }, vim.fs.joinpath(artifacts, "sample", "index.md"))
		local checkout = vim.fs.joinpath(projects, "sample", "develop")
		assert(ensure("sample") == checkout)
		assert(vim.deep_equal(calls, {
			"gh repo view someone/sample-repo --json defaultBranchRef -q .defaultBranchRef.name",
			"gh repo clone someone/sample-repo " .. checkout,
		}), vim.inspect(calls))
	]])
end

T["a missing upstream is created, cloned and given an initial commit"] = function()
	child.lua([[
		local checkout = vim.fs.joinpath(projects, "sample", "main")
		assert(ensure("sample") == checkout)
		assert(vim.deep_equal(calls, {
			"gh repo view sample --json defaultBranchRef -q .defaultBranchRef.name",
			"gh repo create sample --public",
			"gh repo clone sample " .. checkout,
			"git -C " .. checkout .. " symbolic-ref HEAD refs/heads/main",
			"git -C " .. checkout .. " commit --allow-empty -m chore: initial commit",
			"git -C " .. checkout .. " push -u origin main",
		}), vim.inspect(calls))
	]])
end

T["ensure_worktree creates the project before adding the worktree"] = function()
	child.lua([[
		upstream = "main"
		local dir = vim.fs.joinpath(projects, "sample", "feature")
		local done, ok = false, nil
		git.ensure_worktree(dir, function(result) done, ok = true, result end)
		assert(vim.wait(1000, function() return done end))
		local main = vim.fs.joinpath(projects, "sample", "main")
		assert(calls[2] == "gh repo clone sample " .. main, vim.inspect(calls))
		assert(vim.tbl_contains(calls, "git -C " .. main .. " worktree add " .. dir .. " feature"), vim.inspect(calls))
		assert(ok == true)
	]])
end

T["remove_worktree forcibly removes the given worktree"] = function()
	child.lua([[
		package.loaded["neoterm.terms"] = { kill_in_dir = function() end }
		local worktree = vim.fs.joinpath(projects, "sample", "feature")
		local removed
		git.remove_worktree(worktree, function(path) removed = path end, true)
		assert(vim.wait(1000, function() return removed ~= nil end))
		assert(removed == worktree)
		assert(vim.tbl_contains(calls, "git -C " .. worktree .. " worktree remove --force " .. worktree))
	]])
end

return T
