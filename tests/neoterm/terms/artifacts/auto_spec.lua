local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua(
				[[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path]]
			)
			child.lua([[
				local root = vim.fn.tempname()
				vim.env.XDG_STATE_HOME = vim.fs.joinpath(root, "state")
				lock = vim.fs.joinpath(vim.fn.stdpath("state"), "neoterm-auto.lock")
				projects = vim.fs.joinpath(root, "projects")
				artifacts = vim.fs.joinpath(root, "artifacts")
				folder = vim.fs.joinpath(artifacts, "sample", "feature")
				vim.fn.mkdir(vim.fs.joinpath(projects, "sample", "main"), "p")
				vim.fn.mkdir(folder, "p")
				function write(name)
					vim.fn.writefile({ name }, vim.fs.joinpath(folder, name))
				end
				function task()
					local present = {}
					for name in vim.fs.dir(folder) do
						present[name] = true
					end
					return { project = "sample", cwd = folder, path = vim.fs.joinpath(folder, "task.md"), present = present, flat = false }
				end
				notifications = {}
				vim.notify = function(message, level)
					table.insert(notifications, { message = message, level = level })
				end
				started = {}
				package.loaded["neoterm.terms"] = {
					start = function(definition)
						assert(definition.confirm ~= true, "Auto-triggered steps must not confirm")
						table.insert(started, definition.name)
						last_cwd = definition.cwd
						last_definition = definition
					end,
				}
				package.loaded["neoterm.terms.artifacts.tasks"] = {
					executables = function()
						return {}
					end,
				}
				package.loaded["neoterm.config"] = {
					dirs = { projects = projects, artifacts = artifacts },
					default_branches = { "main" },
					steps = {
						{ name = "merge", source = "implementation.md", target = "merge.txt", auto = { "small-change.txt" }, command = { confirm = true, cmd = "merge" } },
						{ name = "always", source = "task.md", auto = {}, target = "done.txt", command = { cmd = "always" } },
						{ name = "manual", source = "implementation.md", command = { cmd = "manual" } },
					},
				}
				write("task.md")
			]])
		end,
		post_once = child.stop,
	},
})

T["fires once when auto and source files are present and targets are absent"] = function()
	child.lua([[
		local auto = require("neoterm.terms.artifacts.auto")
		auto.check({ task() })
		assert(vim.deep_equal(started, { "always:feature:feature" }), vim.inspect(started))
		write("implementation.md")
		auto.check({ task() })
		assert(#started == 1, vim.inspect(started))
		write("small-change.txt")
		auto.check({ task() })
		auto.check({ task() })
		assert(vim.deep_equal(started, { "always:feature:feature", "merge:feature:feature" }), vim.inspect(started))
		write("merge.txt")
		write("done.txt")
		auto.check({ task() })
		assert(#started == 2, vim.inspect(started))
		vim.fn.delete(vim.fs.joinpath(folder, "merge.txt"))
		auto.check({ task() })
		assert(vim.deep_equal(started, { "always:feature:feature", "merge:feature:feature", "merge:feature:feature" }), vim.inspect(started))
	]])
end

T["warns once at start for an empty auto without source and never fires it"] = function()
	child.lua([[
		table.insert(package.loaded["neoterm.config"].steps, { name = "noisy", auto = {}, command = { cmd = "noisy" } })
		local listener
		package.loaded["neoterm.terms.artifacts.tasks"].subscribe = function(callback)
			listener = callback
		end
		package.loaded["neoterm.terms.artifacts.tasks"].start = function() end
		package.loaded["neoterm.terms.artifacts.tasks"].get = function()
			return { task() }
		end
		local auto = require("neoterm.terms.artifacts.auto")
		auto.start()
		auto.start()
		listener()
		assert(#notifications == 1 and notifications[1].level == vim.log.levels.WARN, vim.inspect(notifications))
		assert(notifications[1].message:find("noisy", 1, true))
		assert(not vim.tbl_contains(started, "noisy:feature"), vim.inspect(started))
	]])
end

T["only the lock holder fires, and a stale lock is taken over without refiring"] = function()
	child.lua([[
		vim.fn.mkdir(vim.fs.dirname(lock), "p")
		vim.fn.writefile({ tostring(vim.uv.os_getppid()) }, lock)
		local auto = require("neoterm.terms.artifacts.auto")
		auto.check({ task() })
		assert(#started == 0, vim.inspect(started))
		vim.fn.writefile({ "99999999" }, lock)
		auto.check({ task() })
		assert(#started == 0, vim.inspect(started))
		assert(vim.fn.readfile(lock)[1] == tostring(vim.uv.os_getpid()))
		write("implementation.md")
		write("small-change.txt")
		auto.check({ task() })
		assert(vim.deep_equal(started, { "merge:feature:feature" }), vim.inspect(started))
		auto.release()
		assert(vim.uv.fs_stat(lock) == nil)
	]])
end

T["runs from the task checkout and skips when the checkout is ambiguous"] = function()
	child.lua([[
		table.insert(package.loaded["neoterm.config"].steps, { name = "alt", source = "implementation.md", fork = "alt", command = { cmd = "alt" } })
		local auto = require("neoterm.terms.artifacts.auto")
		auto.check({ task() })
		assert(last_cwd == vim.fs.joinpath(projects, "sample", "main"), last_cwd)
		local feature = vim.fs.joinpath(projects, "sample", "feature")
		vim.fn.mkdir(feature, "p")
		write("implementation.md")
		write("small-change.txt")
		auto.check({ task() })
		assert(started[#started] == "merge:feature:feature" and last_cwd == feature, vim.inspect({ started, last_cwd }))
		vim.fn.writefile({ "1" }, vim.fs.joinpath(folder, "merge.txt"))
		auto.check({ task() })
		vim.fn.delete(vim.fs.joinpath(folder, "merge.txt"))
		vim.fn.mkdir(vim.fs.joinpath(projects, "sample", "feature-alt"), "p")
		local count = #started
		auto.check({ task() })
		assert(#started == count, vim.inspect(started))
		local warning = notifications[#notifications]
		assert(warning.level == vim.log.levels.WARN and warning.message:find("found 2", 1, true), vim.inspect(notifications))
	]])
end

T["runs fork steps in the forked checkout like a manual trigger"] = function()
	child.lua([[
		package.loaded["neoterm.config"].steps = {
			{ name = "plan", source = "task.md", target = "plan.md", fork = true, auto = { "go.txt" }, command = { cmd = "plan" } },
		}
		write("go.txt")
		require("neoterm.terms.artifacts.auto").check({ task() })
		assert(last_definition.name == "plan:feature:feature", vim.inspect(started))
		assert(last_cwd == vim.fs.joinpath(projects, "sample", "feature"), last_cwd)
		assert(last_definition.artifact_dir == folder, last_definition.artifact_dir)
		assert(last_definition.artifact_source == vim.fs.joinpath(folder, "task.md"))
	]])
end

return T
