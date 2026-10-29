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
				artifact_dir = vim.fs.joinpath(artifacts, "utils-mono", "stores", "fix-provider-store")
				vim.fn.mkdir(artifact_dir, "p")
				package.loaded["neoterm.config"] = {
					dirs = { projects = projects, artifacts = artifacts },
					default_branches = { "main" },
				}
				cwd = require("neoterm.terms.artifacts.cwd")
				paths = require("neoterm.terms.artifacts.paths")
				function source(relative)
					local file = vim.fs.joinpath(artifacts, "utils-mono", relative)
					vim.fn.mkdir(vim.fs.dirname(file), "p")
					vim.fn.writefile({ "task" }, file)
					return file
				end
				function checkout(branch)
					local path = vim.fs.joinpath(projects, "utils-mono", branch)
					vim.fn.mkdir(path, "p")
					vim.fn.system({ "git", "init", "-b", branch, path })
					assert(vim.v.shell_error == 0)
					return path
				end
			]])
		end,
		post_case = function()
			child.lua([[vim.fn.delete(root, "rf")]])
		end,
		post_once = child.stop,
	},
})

T["commit messages use the task name and immediate parent scope"] = function()
	child.lua([[
		for _, case in ipairs({
			{ "fix-provider-store/task.md", "fix: provider store" },
			{ "add-provider-store/task.md", "feat: add provider store" },
			{ "stores/fix-provider-store/task.md", "fix(stores): provider store" },
			{ "outer/my-stores/docs-provider-store/task.md", "docs(my stores): provider store" },
			{ "fixation-provider/task.md", "feat: fixation provider" },
		}) do
			assert(paths.commit_message(source(case[1])) == case[2])
		end
		for _, prefix in ipairs({ "feat", "fix", "build", "chore", "ci", "docs", "style", "refactor", "perf", "test", "revert" }) do
			assert(paths.commit_message(source(prefix .. "-change/task.md")) == prefix .. ": change")
		end
		for _, path in ipairs({ "fix-provider.task.md", "fix-provider/plan.md", "task.md" }) do
			assert(not pcall(paths.commit_message, source(path)))
		end
	]])
end

T["nested artifacts and existing forks resolve in both directions"] = function()
	child.lua([[
		local repo = checkout("stores-fix-provider-store")
		assert(cwd.resolve(artifact_dir .. "/task.md") == repo)
		assert(cwd.resolve(artifact_dir) == repo)
		assert(cwd.for_checkout(repo) == artifact_dir)
	]])
end

T["suffix forks retain their artifact link after reloading"] = function()
	child.lua([[
		local repo = checkout("stores-fix-provider-store-a")
		cwd.link(repo, artifact_dir)
		package.loaded["neoterm.terms.artifacts.cwd"] = nil
		cwd = require("neoterm.terms.artifacts.cwd")
		assert(cwd.for_checkout(repo) == artifact_dir)
		assert(cwd.resolve(artifact_dir .. "/task.md") == repo)
	]])
end

T["default and unknown branches retain their artifact locations"] = function()
	child.lua([[
		assert(cwd.for_checkout(checkout("main")) == vim.fs.joinpath(artifacts, "utils-mono"))
		assert(cwd.for_checkout(checkout("other")) == vim.fs.joinpath(artifacts, "utils-mono"))
		assert(cwd.resolve(artifact_dir .. "/task.md") == vim.fs.joinpath(projects, "utils-mono", "main"))
	]])
end

T["source names and fork suffixes use one branch conversion"] = function()
	child.lua([[
		for _, case in ipairs({
			{ "task.md", "main" },
			{ "fix.task.md", "fix" },
			{ "stores/fix-provider-store/task.md", "stores-fix-provider-store" },
			{ "stores/fix-provider-store.plan.md", "stores-fix-provider-store" },
			{ "stores/fix-provider-store/plan.md", "stores-fix-provider-store" },
		}) do
			local file = source(case[1])
			local identity = paths.source(file)
			assert(identity.branch == case[2])
			assert(identity.folder == vim.fs.dirname(file))
			assert(paths.branch(identity, true) == case[2])
			assert(paths.branch(identity, "review") == case[2] .. "-review")
			assert(paths.branch(identity, "{variant}", { variant = "a" }) == case[2] .. "-a")
		end
		assert(not pcall(paths.branch, paths.source(source("task.md")), "{missing}"))
	]])
end

T["configured variants are found before a link is recorded"] = function()
	child.lua([[
		package.loaded["neoterm.config"].steps = {
			{ name = "implement", source = "task.md", fork = "{variant}", variants = { "a", "b" } },
		}
		local file = source("stores/fix-provider-store/task.md")
		local a = checkout("stores-fix-provider-store-a")
		local b = checkout("stores-fix-provider-store-b")
		assert(vim.deep_equal(paths.checkouts(file), { a, b }))
		assert(vim.deep_equal(paths.artifact_folders(a), { artifact_dir }))
		assert(vim.deep_equal(paths.artifact_files(a), { file }))
	]])
end

T["folder conversion includes forks configured for its plan source"] = function()
	child.lua([[
		package.loaded["neoterm.config"].steps = {
			{ name = "implement", source = "plan.md", fork = "review" },
		}
		source("stores/fix-provider-store/plan.md")
		local repo = checkout("stores-fix-provider-store-review")
		assert(vim.deep_equal(paths.checkouts(artifact_dir), { repo }))
		assert(vim.deep_equal(paths.folders("utils-mono", "stores-fix-provider-store-review"), { artifact_dir }))
	]])
end

T["one artifact exposes all forks and navigation asks which checkout"] = function()
	child.lua([[
		local file = source("stores/fix-provider-store/task.md")
		local a, b = checkout("fork-a"), checkout("fork-b")
		paths.link(a, artifact_dir, file)
		paths.link(b, artifact_dir, file)
		assert(vim.deep_equal(cwd.resolve_all(file), { a, b }))
		assert(cwd.resolve(file) == nil)
		vim.ui.select = function(items, _, callback)
			assert(vim.deep_equal(items, { a, b }))
			callback(items[2])
		end
		local selected
		cwd.select_checkout(file, function(path) selected = path end)
		assert(selected == b)
		vim.cmd.cd(a)
		assert(cwd.resolve(file) == a)
	]])
end

T["one checkout retains several sources and folders across reloads"] = function()
	child.lua([[
		local a = source("one/task.md")
		local b = source("two/task.md")
		local repo = checkout("shared")
		paths.link(repo, vim.fs.dirname(a), a)
		paths.link(repo, vim.fs.dirname(b), b)
		paths.link(repo, vim.fs.dirname(a), a)
		package.loaded["neoterm.terms.artifacts.paths"] = nil
		paths = require("neoterm.terms.artifacts.paths")
		assert(vim.deep_equal(paths.artifact_folders(repo), { vim.fs.dirname(a), vim.fs.dirname(b) }))
		assert(vim.deep_equal(paths.artifact_files(repo), { a, b }))
		assert(vim.deep_equal(paths.checkouts(a), { repo }))
		assert(vim.deep_equal(paths.checkouts(b), { repo }))
		assert(cwd.for_checkout(repo) == vim.fs.dirname(a))
		local selected
		vim.ui.select = function(items, _, callback) callback(items[2]) end
		cwd.select_artifacts(repo, function(folder) selected = folder end)
		assert(selected == vim.fs.dirname(a))
	]])
end

T["flattened name collisions stay plural until an explicit link disambiguates"] = function()
	child.lua([[
		local flat = source("one-two/task.md")
		local nested = source("one/two/task.md")
		local repo = checkout("one-two")
		assert(vim.deep_equal(paths.artifact_folders(repo), { vim.fs.dirname(flat), vim.fs.dirname(nested) }))
		paths.link(repo, vim.fs.dirname(nested), nested)
		assert(vim.deep_equal(paths.artifact_folders(repo), { vim.fs.dirname(nested) }))
		assert(vim.deep_equal(paths.checkouts(nested), { repo }))
		assert(not vim.tbl_contains(paths.checkouts(flat), repo))
	]])
end

T["file links distinguish sibling named tasks while retaining related plans"] = function()
	child.lua([[
		local a = source("stores/first.task.md")
		local plan = source("stores/first.plan.md")
		local b = source("stores/second.task.md")
		local repo = checkout("stores-first-a")
		paths.link(repo, vim.fs.dirname(a), a)
		assert(vim.deep_equal(paths.artifact_files(repo), { plan, a }))
		assert(vim.deep_equal(paths.checkouts(plan), { repo }))
		assert(not vim.tbl_contains(paths.checkouts(b), repo))
	]])
end

T["artifact toggle offers all forks and opens the selected checkout"] = function()
	child.lua([[
		local file = source("stores/fix-provider-store/task.md")
		local a, b = checkout("fork-a"), checkout("fork-b")
		paths.link(a, artifact_dir, file)
		paths.link(b, artifact_dir, file)
		package.loaded["neoterm.terms.window"] = {}
		package.loaded["neoterm.helpers.project_file"] = { get_project_file = function(dir)
			assert(dir == b)
			return dir .. "/README.md"
		end }
		local opened
		package.loaded["neoterm.config"].create = function(path) opened = path end
		vim.api.nvim_buf_set_name(0, file)
		vim.ui.select = function(items, _, callback)
			assert(vim.deep_equal(items, { a, b }))
			callback(b)
		end
		local touches = 0
		local artifact = require("neoterm.terms.pseudo_terminal").create(function() touches = touches + 1 end)
		artifact.term:toggle()
		assert(opened == b .. "/README.md")
		assert(touches == 1)
	]])
end

T["checkout toggle opens a linked named task without an existing buffer"] = function()
	child.lua([[
		local file = source("stores/first.task.md")
		source("stores/second.task.md")
		local repo = checkout("stores-first-a")
		paths.link(repo, vim.fs.dirname(file), file)
		local code = repo .. "/main.lua"
		vim.fn.writefile({ "return {}" }, code)
		vim.api.nvim_buf_set_name(0, code)
		package.loaded["neoterm.config"].rooter_patterns = { ".git" }
		local opened
		package.loaded["neoterm.config"].create = function(path) opened = path end
		package.loaded["neoterm.terms.window"] = {}
		local artifact = require("neoterm.terms.pseudo_terminal").create(function() end)
		artifact.term:toggle()
		assert(opened == file)
	]])
end

T["generic terminal creation selects artifacts before expanding its environment"] = function()
	child.lua([[
		local a, b = source("one/task.md"), source("two/task.md")
		local repo = checkout("shared")
		paths.link(repo, vim.fs.dirname(a), a)
		paths.link(repo, vim.fs.dirname(b), b)
		local config = package.loaded["neoterm.config"]
		config.middlewares = {}
		config.on_status = function() end
		local created
		package.loaded["neoterm.terms.create_term"] = { new = function(_, options)
			created = options
			return { focus = function() end }
		end }
		package.loaded["neoterm.terms.window"] = { get_ctx = function() return nil end }
		package.loaded["neoterm.terms.get_commands"] = { get_commands = function(_, _, callback)
			callback({ shell = { key = "shell", cwd = repo, cmd = "echo", env = { ARTIFACTS = "{artifacts}" } } })
		end }
		vim.ui.select = function() error("Artifact folder selection must be automatic") end
		local terms = require("neoterm.terms")
		terms.focus({ key = "shell", cwd = repo, instance_count = 2 })
		assert(created.env.ARTIFACTS == vim.fs.dirname(a))
	]])
end

T["harness and steps derive the same checkout from a named nested plan"] = function()
	child.lua([[
		local file = source("stores/fix-provider-store.plan.md")
		local repo = checkout("stores-fix-provider-store")
		vim.api.nvim_buf_set_name(0, file)
		local focused
		package.loaded["neoterm.terms"] = { focus = function(command) focused = command end }
		require("neoterm.harness").with_worktree()
		assert(focused.cwd == repo)
		assert(focused.artifact_source == file)
		assert(vim.deep_equal(paths.artifact_folders(repo), { vim.fs.dirname(file) }))
		package.loaded["neoterm.terms.artifacts.tasks"] = { executables = function() return {} end }
		local definitions = require("neoterm.terms.artifacts.commands").for_file({
			cwd = repo, file = file,
			steps = { { name = "implement", source = "plan.md", fork = true, command = "echo" } },
		})
		assert(#definitions == 1)
		assert(definitions[1].cwd == focused.cwd)
	]])
end

T["equivalent saved locations are deduplicated before navigation"] = function()
	child.lua([[
		local file = source("one/task.md")
		local folder = vim.fs.dirname(file)
		local alias = vim.fs.joinpath(artifacts, "utils-mono", "alias")
		assert(vim.uv.fs_symlink(folder, alias))
		local repo = checkout("shared")
		local key = "branch.shared.neoterm-artifacts"
		for _, path in ipairs({ folder, folder .. "/", folder .. "/.", alias }) do
			vim.fn.system({ "git", "-C", repo, "config", "--add", key, path })
			assert(vim.v.shell_error == 0)
		end
		paths.link(repo, folder, file)
		paths.link(repo, alias, alias .. "/task.md")
		local saved = vim.fn.systemlist({ "git", "-C", repo, "config", "--get-all", "branch.shared.neoterm-artifact-source" })
		assert(#saved == 1)
		local folders = paths.artifact_folders(repo)
		assert(vim.deep_equal(folders, { folder }))
		assert(vim.deep_equal(paths.artifact_files(repo), { file }))
		assert(vim.deep_equal(paths.checkouts(file), { repo }))
		vim.ui.select = function() error("A single location must not prompt") end
		local selected
		cwd.select_artifacts(repo, function(path) selected = path end)
		assert(selected == folder)
		cwd.select_checkout(file, function(path) selected = path end)
		assert(selected == repo)
	]])
end

T["the deepest available artifact folder is selected automatically"] = function()
	child.lua([[
		package.loaded["neoterm.config"].steps = {
			{ name = "implement", source = "task.md", fork = "{variant}", variants = { "codex" } },
		}
		source("stores/fix-provider-store/task.md")
		local output = source("stores-fix-provider-store-codex/index.md")
		local repo = checkout("stores-fix-provider-store-codex")
		vim.ui.select = function() error("Artifact folder selection must be automatic") end
		local selected
		cwd.select_artifacts(repo, function(folder) selected = folder end)
		assert(selected == artifact_dir)
	]])
end

T["missing artifact folders fall back to a repo level index"] = function()
	child.lua([[
		local repo = checkout("new-branch")
		local folder = vim.fs.joinpath(artifacts, "utils-mono")
		assert(paths.preferred_folder(repo) == folder)
		cwd.select_artifacts(repo, function(selected) assert(selected == folder) end)
		assert(vim.fn.filereadable(vim.fs.joinpath(folder, "index.md")) == 1)
		local selected
		cwd.select_artifact_file(repo, cwd.for_checkout(repo), function(file) selected = file end)
		assert(selected == vim.fs.joinpath(folder, "index.md"))
	]])
end

T["checkout scans reuse git queries and refresh between scans"] = function()
	child.lua([[
		local first = source("first/task.md")
		local second = source("second/task.md")
		local repo = checkout("shared")
		paths.link(repo, vim.fs.dirname(first))
		local expected_second = paths.checkouts(second)
		local system, systemlist = vim.fn.system, vim.fn.systemlist
		local calls = 0
		vim.fn.system = function(...)
			calls = calls + 1
			return system(...)
		end
		vim.fn.systemlist = function(...)
			calls = calls + 1
			return systemlist(...)
		end
		local resolve = paths.checkout_resolver()
		assert(vim.deep_equal(resolve(first), { repo }))
		local initial_calls = calls
		assert(initial_calls == 3, tostring(initial_calls))
		assert(vim.deep_equal(resolve(second), expected_second))
		assert(vim.deep_equal(resolve(vim.fs.dirname(first)), { repo }))
		assert(calls == initial_calls)
		paths.link(repo, vim.fs.dirname(second))
		assert(vim.deep_equal(paths.checkout_resolver()(second), { repo }))
		assert(vim.deep_equal(paths.checkouts(second), { repo }))
	]])
end

return T
