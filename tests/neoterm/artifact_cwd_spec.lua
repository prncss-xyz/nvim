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
				function branch_of(relative)
					return paths.source(source(relative)).branch
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

T["commit messages use the scope and the last step of the task"] = function()
	child.lua([[
		for _, case in ipairs({
			{ "stores/fix-provider-store/task.md", "fix(stores): provider-store" },
			{ "stores/fix-provider-store/plan.md", "fix(stores): provider-store" },
			{ "stores/fix-provider-store/0.task.md", "fix(stores): provider-store" },
			{ "stores/fix-provider-store/notes/review.plan.md", "fix(stores): provider-store" },
			{ "stores/add-provider-store/task.md", "feat(stores): add-provider-store" },
			{ "stores/01 fix-provider/task.md", "fix(stores): provider" },
			{ "stores/fixation-provider/task.md", "feat(stores): fixation-provider" },
			{ "outer/my-stores/docs-provider-store/task.md", "docs(outer): provider-store" },
			{ "misc/fix-provider/task.md", "fix: provider" },
		}) do
			local message = paths.commit_message(source(case[1]))
			assert(message == case[2], message)
		end
		for _, prefix in ipairs({ "feat", "fix", "build", "chore", "ci", "docs", "style", "refactor", "perf", "test", "revert" }) do
			assert(paths.commit_message(source("scope/" .. prefix .. "-change/task.md")) == prefix .. "(scope): change")
		end
		for _, path in ipairs({ "task.md", "stores/task.md", "stores/fix-provider.task.md", "fix-provider.task.md" }) do
			assert(not pcall(paths.commit_message, source(path)))
		end
		vim.fn.writefile({ "First line", "", "Second line", "" }, vim.fs.joinpath(artifact_dir, "implementation.md"))
		local message = paths.commit_message(vim.fs.joinpath(artifact_dir, "implementation.md"))
		assert(message == "fix(stores): provider-store\n\nFirst line\n\nSecond line", message)
	]])
end

T["nested artifacts and existing forks resolve in both directions"] = function()
	child.lua([[
		local repo = checkout(branch_of("stores/fix-provider-store/task.md"))
		assert(cwd.resolve(artifact_dir .. "/task.md") == repo)
		assert(cwd.resolve(artifact_dir) == repo)
		assert(cwd.for_checkout(repo) == artifact_dir)
	]])
end

T["linked checkouts retain their artifact link after reloading"] = function()
	child.lua([[
		local repo = checkout("old-name")
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

T["branches hash the path from the scope and slug the last step"] = function()
	child.lua([[
		local hash = require("neoterm.helpers.hash")
		local expected = hash("stores") .. "-fix-provider-store"
		for _, case in ipairs({
			{ "task.md", "main" },
			{ "fix.task.md", "main" },
			{ "stores/task.md", "main" },
			{ "stores/fix.task.md", "main" },
			{ "stores/fix-provider-store/task.md", expected },
			{ "stores/fix-provider-store/plan.md", expected },
			{ "stores/fix-provider-store/fix.task.md", expected },
			{ "stores/fix-provider-store/deep/er/0.task.md", expected },
			{ "outer/inner/02 Fix  the thing!/task.md", hash("outer/inner") .. "-Fix-the-thing" },
		}) do
			local file = source(case[1])
			local identity = paths.source(file)
			assert(identity.branch == case[2], case[1] .. ": " .. identity.branch)
			assert(identity.default == (case[2] == "main"))
			assert(identity.folder == vim.fs.dirname(file))
			assert(paths.branch(identity) == case[2])
		end
		assert(branch_of("misc/fix-provider/task.md") ~= branch_of("other/fix-provider/task.md"))
		assert(paths.source(source("fix-provider-store/deep/0.task.md")).default)
		local dotted = vim.fs.joinpath(artifacts, "flies.nvim", "scope", "fix-x", "task.md")
		vim.fn.mkdir(vim.fs.dirname(dotted), "p")
		vim.fn.writefile({ "task" }, dotted)
		local identity = paths.source(dotted)
		assert(identity.project == "flies.nvim")
		assert(identity.branch == hash("scope") .. "-fix-x")
		package.loaded["neoterm.config"].default_branches = { "main", "master" }
		checkout("master")
		assert(branch_of("stores/task.md") == "master")
	]])
end

T["github repos come from the project index frontmatter"] = function()
	child.lua([[
		assert(paths.github_repo("utils-mono") == "utils-mono")
		local index = vim.fs.joinpath(artifacts, "utils-mono", "index.md")
		vim.fn.writefile({ "# Utils" }, index)
		assert(paths.github_repo("utils-mono") == "utils-mono")
		vim.fn.writefile({ "---", "status: ready", "---", "" }, index)
		assert(paths.github_repo("utils-mono") == "utils-mono")
		vim.fn.writefile({ "---", "github: someone/utils", "---", "" }, index)
		assert(paths.github_repo("utils-mono") == "someone/utils")
		vim.fn.writefile({ "---", "github: utils", "---", "" }, index)
		assert(paths.github_repo("utils-mono") == "utils")
	]])
end

T["fork checkouts are found before a link is recorded"] = function()
	child.lua([[
		local file = source("stores/fix-provider-store/task.md")
		local repo = checkout(paths.source(file).branch)
		assert(vim.deep_equal(paths.checkouts(file), { repo }))
		assert(vim.deep_equal(paths.artifact_folders(repo), { artifact_dir }))
		assert(vim.deep_equal(paths.artifact_files(repo), { file }))
	]])
end

T["tasks that do not fork contribute no branch"] = function()
	child.lua([[
		local file = source("stores/fix-provider-store/task.md")
		vim.fn.writefile({ "---", "fork: false", "---", "task" }, file)
		local plan = source("stores/fix-provider-store/plan.md")
		local repo = checkout(paths.source(file).branch)
		assert(vim.deep_equal(paths.branches(paths.source(file)), {}))
		assert(vim.deep_equal(paths.branches(paths.source(plan)), {}))
		assert(not vim.tbl_contains(paths.checkouts(file), repo))
		assert(not vim.tbl_contains(paths.checkouts(plan), repo))
	]])
end

T["folder conversion finds the folders of a branch"] = function()
	child.lua([[
		local plan = source("stores/fix-provider-store/plan.md")
		local branch = paths.source(plan).branch
		local repo = checkout(branch)
		assert(vim.deep_equal(paths.checkouts(artifact_dir), { repo }))
		assert(vim.deep_equal(paths.folders("utils-mono", branch), { artifact_dir }))
		assert(vim.deep_equal(paths.folders("utils-mono", "unknown"), {}))
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

T["the same last step in different scopes maps to different checkouts"] = function()
	child.lua([[
		local first = source("one/fix-x/task.md")
		local second = source("two/fix-x/task.md")
		local repo = checkout(paths.source(first).branch)
		assert(vim.deep_equal(paths.artifact_folders(repo), { vim.fs.dirname(first) }))
		assert(vim.deep_equal(paths.checkouts(first), { repo }))
		assert(not vim.tbl_contains(paths.checkouts(second), repo))
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
		source("stores/fix-provider-store/task.md")
		local file = source("stores/fix-provider-store/review.plan.md")
		local repo = checkout(paths.source(file).branch)
		vim.api.nvim_buf_set_name(0, file)
		local focused
		package.loaded["neoterm.terms"] = { focus = function(command) focused = command end }
		require("neoterm.harness").with_worktree()
		assert(focused.cwd == repo)
		assert(focused.artifact_source == file)
		assert(vim.deep_equal(paths.artifact_folders(repo), { vim.fs.dirname(file) }))
		require("neoterm.terms.artifacts.tasks").executables = function() return {} end
		local definitions = require("neoterm.terms.artifacts.commands").for_file({
			cwd = repo, file = file,
			steps = { { name = "implement", source = "plan.md", command = "echo" } },
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
		local file = source("stores/fix-provider-store/task.md")
		local notes = source("stores/fix-provider-store/notes/review.plan.md")
		local repo = checkout(paths.source(file).branch)
		vim.ui.select = function() error("Artifact folder selection must be automatic") end
		local selected
		cwd.select_artifacts(repo, function(folder) selected = folder end)
		assert(selected == vim.fs.dirname(notes))
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
