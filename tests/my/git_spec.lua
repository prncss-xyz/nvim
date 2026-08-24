local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

				function run_git_case(config)
					local calls = { mkdir = {}, notify = {}, rename = {}, system = {}, symlink = {} }
					vim.v = { shell_error = 0 }
					package.loaded["my.git"] = nil
					package.loaded["my.parameters"] = { dirs = { projects = "/projects", artifacts = "/artifacts" } }
					package.loaded["my.create"] = {
						create = function(path)
							calls.created = path
						end,
					}

					vim.ui.input = function(_, callback)
						callback(config.input)
					end
					vim.notify = function(message, level)
						table.insert(calls.notify, { message, level })
					end
					vim.fn.filereadable = function(path)
						return config.readable and config.readable[path] or 0
					end
					vim.fn.isdirectory = function(path)
						return config.directories and config.directories[path] or 0
					end
					vim.fn.mkdir = function(path, flags)
						table.insert(calls.mkdir, { path, flags })
						if config.mkdir_failure == path then
							return 0
						end
						return 1
					end
					vim.fn.rename = function(from, to)
						table.insert(calls.rename, { from, to })
						return 0
					end
					vim.fn.fnameescape = function(path)
						return path
					end
					vim.fn.shellescape = function(value)
						return "'" .. value .. "'"
					end
					vim.fn.expand = function()
						return config.current_file or ""
					end
					vim.uv.fs_lstat = function(path)
						if config.existing and config.existing[path] then
							return { type = config.existing[path] }
						end
					end
					vim.uv.fs_symlink = function(target, path)
						table.insert(calls.symlink, { target, path })
						if config.symlink_failure then
							return nil, config.symlink_failure
						end
						return true
					end
					vim.fn.system = function(command)
						table.insert(calls.system, command)
						local key = type(command) == "table" and table.concat(command, " ") or command
						local response = config.system and config.system[key] or nil
						if type(response) == "table" then
							vim.v.shell_error = response.error or 0
							return response.output or ""
						end
						vim.v.shell_error = 0
						return response or ""
					end

					local git = require("my.git")
					if config.operation == "clone" then
						git.clone_github()
					else
						git.create_worktree(config.branch, function(path)
							calls.success = path
						end)
					end
					return calls
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["clone creates repository artifacts before opening a file"] = function()
	local result = child.lua_get([[run_git_case({
		operation = "clone",
		input = "owner/repo",
		system = {
			["gh repo view owner/repo --json defaultBranchRef -q .defaultBranchRef.name"] = "main\n",
			["git -C /projects/owner/repo/main ls-files"] = "lua/init.lua\n",
		},
	})]])

	assert.same({
		{ "/projects/owner/repo", "p" },
		{ "/artifacts/repo/main", "p" },
	}, result.mkdir)
	assert.same({ { "../../../../artifacts/repo", "/projects/owner/repo/main/.artifacts" } }, result.symlink)
	assert.same("/projects/owner/repo/main/lua/init.lua", result.created)
end

T["new repository creates artifacts at its final path"] = function()
	local result = child.lua_get([[run_git_case({
		operation = "clone",
		input = "repo",
		directories = { ["/projects/repo"] = 1 },
		system = {
			["gh repo view repo --json defaultBranchRef -q .defaultBranchRef.name"] = { error = 1 },
			["git -C /projects/repo ls-files"] = "README.md\n",
		},
	})]])

	assert.same({ "/artifacts/repo/main", "p" }, result.mkdir[2])
	assert.same("/projects/repo/README.md", result.created)
end

T["existing repository artifacts are untouched"] = function()
	local result = child.lua_get([[run_git_case({
		operation = "clone",
		input = "owner/repo",
		existing = { ["/projects/owner/repo/main/.artifacts"] = "link" },
		system = {
			["gh repo view owner/repo --json defaultBranchRef -q .defaultBranchRef.name"] = "main\n",
			["git -C /projects/owner/repo/main ls-files"] = "init.lua\n",
		},
	})]])

	assert.same(2, #result.mkdir)
	assert.same({}, result.symlink)
end

T["worktree links artifacts relatively to the main repository"] = function()
	local result = child.lua_get([[run_git_case({
		operation = "worktree",
		branch = "feature",
		current_file = "/repos/main/lua/init.lua",
		system = {
			["git rev-parse --show-toplevel"] = "/repos/main\n",
			["git -C /repos/main rev-parse --path-format=absolute --git-common-dir"] = "/repos/main/.git\n",
			["git rev-parse --verify origin/feature"] = { error = 1 },
			["git worktree add /repos/feature -b feature"] = "ok",
			["git -C /repos/feature ls-files"] = "lua/init.lua\n",
		},
	})]])

	assert.same({ { "../../artifacts/repos", "/repos/feature/.artifacts" } }, result.symlink)
	assert.same("/repos/feature/lua/init.lua", result.success)
end

T["linked worktree resolves artifacts from the common git directory"] = function()
	local result = child.lua_get([[run_git_case({
		operation = "worktree",
		branch = "next",
		current_file = "/repos/feature/lua/init.lua",
		system = {
			["git rev-parse --show-toplevel"] = "/repos/feature\n",
			["git -C /repos/feature rev-parse --path-format=absolute --git-common-dir"] = "/repos/main/.git\n",
			["git rev-parse --verify origin/next"] = { error = 1 },
			["git worktree add /repos/next -b next"] = "ok",
			["git -C /repos/next ls-files"] = "lua/init.lua\n",
		},
	})]])

	assert.same({ { "../../artifacts/repos", "/repos/next/.artifacts" } }, result.symlink)
end

T["existing worktree artifact path is untouched"] = function()
	local result = child.lua_get([[run_git_case({
		operation = "worktree",
		branch = "feature",
		current_file = "/repos/main/init.lua",
		existing = { ["/repos/feature/.artifacts"] = "link" },
		system = {
			["git rev-parse --show-toplevel"] = "/repos/main\n",
			["git -C /repos/main rev-parse --path-format=absolute --git-common-dir"] = "/repos/main/.git\n",
			["git rev-parse --verify origin/feature"] = { error = 1 },
			["git worktree add /repos/feature -b feature"] = "ok",
		},
	})]])

	assert.same({}, result.symlink)
	assert.same("/repos/feature/README.md", result.success)
end

T["artifact setup failures warn without changing success"] = function()
	local clone = child.lua_get([[run_git_case({
		operation = "clone",
		input = "owner/repo",
		mkdir_failure = "/artifacts/repo/main",
		system = {
			["gh repo view owner/repo --json defaultBranchRef -q .defaultBranchRef.name"] = "main\n",
			["git -C /projects/owner/repo/main ls-files"] = "init.lua\n",
		},
	})]])
	assert.same(vim.log.levels.WARN, clone.notify[1][2])
	assert.same("/projects/owner/repo/main/init.lua", clone.created)

	local worktree = child.lua_get([[run_git_case({
		operation = "worktree",
		branch = "feature",
		current_file = "/repos/main/init.lua",
		symlink_failure = "permission denied",
		system = {
			["git rev-parse --show-toplevel"] = "/repos/main\n",
			["git -C /repos/main rev-parse --path-format=absolute --git-common-dir"] = "/repos/main/.git\n",
			["git rev-parse --verify origin/feature"] = { error = 1 },
			["git worktree add /repos/feature -b feature"] = "ok",
		},
	})]])
	assert.same(vim.log.levels.WARN, worktree.notify[1][2])
	assert.same("/repos/feature/README.md", worktree.success)
end

T["worktree artifact setup does not depend on common git directory discovery"] = function()
	local result = child.lua_get([[run_git_case({
		operation = "worktree",
		branch = "feature",
		current_file = "/repos/main/init.lua",
		system = {
			["git rev-parse --show-toplevel"] = "/repos/main\n",
			["git -C /repos/main rev-parse --path-format=absolute --git-common-dir"] = { error = 1, output = "unsupported" },
			["git -C /repos/main rev-parse --git-common-dir"] = { error = 1, output = "failed" },
			["git rev-parse --verify origin/feature"] = { error = 1 },
			["git worktree add /repos/feature -b feature"] = "ok",
		},
	})]])

	assert.same({ { "../../artifacts/repos", "/repos/feature/.artifacts" } }, result.symlink)
	assert.same({}, result.notify)
	assert.same("/repos/feature/README.md", result.success)
end

return T
