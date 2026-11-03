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
		child.lua_get("(function() local task = tasks.next_auto() return { task.parts, task.auto } end)()"),
		{ { "a", "m" }, { step = "implement", variant = "fast" } }
	)
	child.lua([[
		write("a/m/n/task.md", { "---", "auto: review", "---" })
		vim.wait(3000, function() return tasks.next_auto().parts[3] == "n" end, 20)
	]])
	MiniTest.expect.equality(
		child.lua_get("(function() local task = tasks.next_auto() return { task.parts, task.auto } end)()"),
		{ { "a", "m", "n" }, { step = "review" } }
	)
	MiniTest.expect.equality(
		child.lua_get(
			"tasks.next_auto(function(task) return task.auto.step ~= 'review' and task.parts[2] ~= 'm' end).parts"
		),
		{ "a", "z" }
	)
end

return T
