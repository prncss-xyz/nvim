local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. package.path
				root = vim.fn.tempname()
				vim.fn.mkdir(root, "p")
				tasks_config = {
					default_status = "inbox",
					status = {
						{ name = "inbox", modes = { "focus" } },
						{ name = "hidden", modes = { "standup" }, enabled = false },
						{ name = "ready", modes = { "focus", "standup" } },
						{ name = "review", files = { "implementation.md" } },
						{ name = "done", files = { "merge.txt" } },
						{ name = "aborted" },
					},
				}
				package.loaded["neoterm.config"] = {
					dirs = { artifacts = root },
					tasks = tasks_config,
				}
				statuses = require("neoterm.terms.artifacts.statuses")
				function write(path, lines)
					vim.fn.mkdir(vim.fs.dirname(root .. "/" .. path), "p")
					vim.fn.writefile(lines, root .. "/" .. path)
				end
				function task_statuses()
					local result = {}
					for _, task in ipairs(require("neoterm.terms.artifacts.tasks").get()) do
						result[table.concat(task.parts, "/")] = task.logical_status
					end
					return result
				end
				function wait_for(path, status)
					return vim.wait(3000, function()
						return task_statuses()[path] == status
					end, 20)
				end
			]])
		end,
		post_case = function()
			child.lua([[vim.fn.delete(root, "rf")]])
		end,
		post_once = child.stop,
	},
})

T["modes derive from status entries and all holds every enabled status"] = function()
	MiniTest.expect.equality(child.lua_get("statuses.modes()"), {
		all = { "inbox", "ready", "review", "done", "aborted" },
		focus = { "inbox", "ready" },
		standup = { "ready" },
	})
end

T["all can be disabled without affecting status order"] = function()
	child.lua([[tasks_config.modes = { { name = "all", enabled = false } }]])
	MiniTest.expect.equality(child.lua_get("statuses.modes().all"), vim.NIL)
	MiniTest.expect.equality(child.lua_get("statuses.order().done"), 4)
end

T["all is reserved as a status name"] = function()
	child.lua([[tasks_config.status = { { name = "all", enabled = true } }]])
	MiniTest.expect.error(function()
		child.lua("statuses.list()")
	end, "reserved")
end

T["the latest listed status wins between files and the given status"] = function()
	child.lua([[
		results = {
			statuses.resolve("ready", {}),
			statuses.resolve("ready", { ["implementation.md"] = true }),
			statuses.resolve("ready", { ["implementation.md"] = true, ["merge.txt"] = true }),
			statuses.resolve("aborted", { ["merge.txt"] = true }),
			statuses.resolve("draft", { ["merge.txt"] = true }),
		}
	]])
	MiniTest.expect.equality(child.lua_get("results"), { "ready", "review", "done", "aborted", "draft" })
end

T["directory and flat tasks only match their own files"] = function()
	child.lua([[
		write("project/implemented/task.md", { "---", "status: ready", "---" })
		write("project/implemented/implementation.md", {})
		write("project/merged/task.md", {})
		write("project/merged/merge.txt", { "abc" })
		write("project/flat.task.md", {})
		write("project/flat.merge.txt", { "abc" })
		write("project/other.task.md", { "---", "status: ready", "---" })
		settled = wait_for("project/other", "ready")
			and wait_for("project/flat", "done")
			and wait_for("project/merged", "done")
			and wait_for("project/implemented", "review")
	]])
	MiniTest.expect.equality(child.lua_get("settled"), true)
end

T["status follows files created and deleted after startup"] = function()
	child.lua([[
		write("project/live/task.md", { "---", "status: ready", "---" })
		write("project/flat.task.md", { "---", "status: ready", "---" })
		started = wait_for("project/live", "ready") and wait_for("project/flat", "ready")
		write("project/live/merge.txt", { "abc" })
		created = wait_for("project/live", "done")
		vim.fn.delete(root .. "/project/live/merge.txt")
		deleted = wait_for("project/live", "ready")
		write("project/flat.implementation.md", {})
		flat = wait_for("project/flat", "review")
	]])
	MiniTest.expect.equality(child.lua_get("{ started, created, deleted, flat }"), { true, true, true, true })
end

T["branch directories promote tasks and follow project entries"] = function()
	child.lua([[
		local config = package.loaded["neoterm.config"]
		config.dirs.projects = root .. "/checkouts"
		config.default_branches = { "main" }
		tasks_config.forked = "ready"
		vim.fn.mkdir(config.dirs.projects, "p")
		write("project/nested/live/task.md", {})
		write("project/flat.task.md", {})
		started = wait_for("project/nested/live", "inbox") and wait_for("project/flat", "inbox")
		local paths = require("neoterm.terms.artifacts.paths")
		local checkout = paths.checkout("project", paths.source(root .. "/project/nested/live/task.md").branch)
		vim.fn.mkdir(checkout, "p")
		created = wait_for("project/nested/live", "ready")
		local flat_checkout = paths.checkout("project", paths.source(root .. "/project/flat.task.md").branch)
		vim.fn.mkdir(flat_checkout, "p")
		flat = wait_for("project/flat", "inbox")
		write("project/flat.task.md", { "---", "status: review", "---" })
		write("project/nested/live/implementation.md", {})
		later = wait_for("project/nested/live", "review") and wait_for("project/flat", "review")
		vim.fn.delete(root .. "/project/nested/live/implementation.md")
		restored = wait_for("project/nested/live", "ready")
		vim.fn.delete(checkout, "rf")
		deleted = wait_for("project/nested/live", "inbox")
	]])
	MiniTest.expect.equality(
		child.lua_get("{ started, created, flat, later, restored, deleted }"),
		{ true, true, true, true, true, true }
	)
end

T["default branch checkouts do not promote tasks to the forked status"] = function()
	child.lua([[
		local config = package.loaded["neoterm.config"]
		config.dirs.projects = root .. "/checkouts"
		config.default_branches = { "main", "master" }
		tasks_config.forked = "ready"
		vim.fn.mkdir(config.dirs.projects .. "/project/master", "p")
		write("project/task.md", {})
		write("project/scope/task.md", {})
		write("project/scope/implementation.md", {})
		write("project/scope/feature/task.md", {})
		local paths = require("neoterm.terms.artifacts.paths")
		local branch = paths.source(root .. "/project/scope/feature/task.md").branch
		vim.fn.mkdir(paths.checkout("project", branch), "p")
		settled = wait_for("project/scope/feature", "ready")
			and wait_for("project", "inbox")
			and wait_for("project/scope", "review")
	]])
	MiniTest.expect.equality(child.lua_get("settled"), true)
end

T["dependency blocking competes with task statuses by configuration order"] = function()
	child.lua([[
		table.insert(tasks_config.status, 2, { name = "blocked" })
		tasks_config.blocking = { status = "blocked", unblock = { "done" } }
		write("project/dependency/task.md", {})
		for name, status in pairs({ early = "inbox", later = "ready", files = "inbox", unknown = "custom" }) do
			write("project/" .. name .. "/task.md", {
				"---", "status: " .. status,
				"dependencies: project/dependency/task.md", "---",
			})
		end
		write("project/files/implementation.md", {})
		blocked = wait_for("project/early", "blocked")
			and wait_for("project/later", "ready")
			and wait_for("project/files", "review")
			and wait_for("project/unknown", "custom")
		write("project/dependency/task.md", { "---", "status: done", "---" })
		unblocked = wait_for("project/early", "inbox") and wait_for("project/dependency", "done")
		write("project/dependency/task.md", {})
		reblocked = wait_for("project/early", "blocked") and wait_for("project/later", "ready")
	]])
	MiniTest.expect.equality(child.lua_get("{ blocked, unblocked, reblocked }"), { true, true, true })
end

T["next auto task prefers the first directory at every level, then the deepest task"] = function()
	child.lua([[
		write("b/task.md", { "---", "auto: plan", "---" })
		write("a/z/task.md", { "---", "auto: plan", "---" })
		write("a/task.md", { "---", "auto: plan", "---" })
		write("a/m/task.md", { "---", "status: ready", "auto: implement:fast", "---" })
		write("a/m/n/task.md", { "---", "status: ready", "---" })
		write("a/c.task.md", { "---", "status: ready", "---" })
		tasks = require("neoterm.terms.artifacts.tasks")
		settled = wait_for("a/c", "ready")
	]])
	MiniTest.expect.equality(child.lua_get("settled"), true)
	MiniTest.expect.equality(
		child.lua_get("(function() local task = tasks.auto_tasks()[1] return { task.parts, task.auto } end)()"),
		{ { "a", "m" }, { step = "implement", variant = "fast" } }
	)
	child.lua([[
		write("a/m/n/task.md", { "---", "auto: review", "---" })
		vim.wait(3000, function() return tasks.auto_tasks()[1].parts[3] == "n" end, 20)
	]])
	MiniTest.expect.equality(
		child.lua_get("(function() local task = tasks.auto_tasks()[1] return { task.parts, task.auto } end)()"),
		{ { "a", "m", "n" }, { step = "review" } }
	)
	MiniTest.expect.equality(
		child.lua_get(
			"tasks.auto_tasks(function(task) return task.auto.step ~= 'review' and task.parts[2] ~= 'm' end)[1].parts"
		),
		{ "a", "z" }
	)
	MiniTest.expect.equality(
		child.lua_get("vim.tbl_map(function(task) return table.concat(task.parts, '/') end, tasks.auto_tasks())"),
		{ "a/m/n", "a/m", "a/z", "a", "b" }
	)
end

return T
