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
				folder = vim.fs.joinpath(artifacts, "sample", "scope", "feature")
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
				require("neoterm.terms.artifacts.tasks").executables = function()
					return {}
				end
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
				branch = require("neoterm.terms.artifacts.paths").source(vim.fs.joinpath(folder, "task.md")).branch
				function name(step)
					return step .. ":" .. branch .. ":feature"
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["fires once when auto and source files are present and targets are absent"] = function()
	child.lua([[
		local auto = require("neoterm.terms.artifacts.auto")
		auto.check({ task() })
		assert(vim.deep_equal(started, { name("always") }), vim.inspect(started))
		write("implementation.md")
		auto.check({ task() })
		assert(#started == 1, vim.inspect(started))
		write("small-change.txt")
		auto.check({ task() })
		auto.check({ task() })
		assert(vim.deep_equal(started, { name("always"), name("merge") }), vim.inspect(started))
		write("merge.txt")
		write("done.txt")
		auto.check({ task() })
		assert(#started == 2, vim.inspect(started))
		vim.fn.delete(vim.fs.joinpath(folder, "merge.txt"))
		auto.check({ task() })
		assert(vim.deep_equal(started, { name("always"), name("merge"), name("merge") }), vim.inspect(started))
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
		assert(vim.deep_equal(started, { name("merge") }), vim.inspect(started))
		auto.release()
		assert(vim.uv.fs_stat(lock) == nil)
	]])
end

T["runs from the task checkout and skips when the checkout is ambiguous"] = function()
	child.lua([[
		local auto = require("neoterm.terms.artifacts.auto")
		local feature = vim.fs.joinpath(projects, "sample", branch)
		auto.check({ task() })
		assert(last_cwd == feature, last_cwd)
		vim.fn.mkdir(feature, "p")
		write("implementation.md")
		write("small-change.txt")
		auto.check({ task() })
		assert(started[#started] == name("merge") and last_cwd == feature, vim.inspect({ started, last_cwd }))
		vim.fn.writefile({ "1" }, vim.fs.joinpath(folder, "merge.txt"))
		auto.check({ task() })
		vim.fn.delete(vim.fs.joinpath(folder, "merge.txt"))
		local paths = require("neoterm.terms.artifacts.paths")
		for _, path in ipairs({ feature, vim.fs.joinpath(projects, "sample", "other") }) do
			vim.fn.system({ "git", "init", "-b", vim.fs.basename(path), path })
			paths.link(path, folder, vim.fs.joinpath(folder, "implementation.md"))
		end
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
			{ name = "plan", source = "task.md", target = "plan.md", auto = { "go.txt" }, command = { cmd = "plan" } },
		}
		write("go.txt")
		require("neoterm.terms.artifacts.auto").check({ task() })
		assert(last_definition.name == name("plan"), vim.inspect(started))
		assert(last_cwd == vim.fs.joinpath(projects, "sample", branch), last_cwd)
		assert(last_definition.artifact_dir == folder, last_definition.artifact_dir)
		assert(last_definition.artifact_source == vim.fs.joinpath(folder, "task.md"))
	]])
end

T["trigger next runs the first task whose auto step is enabled for it"] = function()
	child.lua([[
		package.loaded["neoterm.config"].steps = {
			{ name = "plan", source = "task.md", target = "plan.md", variants = { "fast", "slow" }, command = { cmd = "plan {variant}" } },
			{ name = "merge", source = "implementation.md", target = "merge.txt", command = { cmd = "merge" } },
			{ name = "review", source = "implementation.md", command = { cmd = "review {source}" } },
		}
		local other = vim.fs.joinpath(artifacts, "sample", "other")
		vim.fn.mkdir(other, "p")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(other, "task.md"))
		vim.fn.writefile({ "implementation" }, vim.fs.joinpath(other, "implementation.md"))
		vim.fn.writefile({ "flat" }, vim.fs.joinpath(folder, "flat.task.md"))
		vim.fn.writefile({ "implementation" }, vim.fs.joinpath(folder, "flat.implementation.md"))
		local function entry(cwd, auto, extra)
			local present = {}
			for name in vim.fs.dir(cwd) do
				present[name] = true
			end
			return vim.tbl_extend("force", {
				project = "sample",
				cwd = cwd,
				path = vim.fs.joinpath(cwd, "task.md"),
				present = present,
				flat = false,
				auto = auto,
			}, extra or {})
		end
		local entries
		package.loaded["neoterm.terms.artifacts.tasks"].next_auto = function(predicate)
			return vim.iter(entries):find(predicate)
		end
		local auto = require("neoterm.terms.artifacts.auto")
		local main = vim.fs.joinpath(projects, "sample", "main")
		local fork = vim.fs.joinpath(projects, "sample", branch)
		local function triggered()
			local count = #started
			auto.trigger_next()
			assert(#started == count + 1, vim.inspect(started))
			return last_definition.cmd, last_cwd
		end
		local flat = entry(folder, { step = "review" }, {
			path = vim.fs.joinpath(folder, "flat.task.md"),
			present = { ["task.md"] = true, ["implementation.md"] = true },
			flat = true,
			branch = "flat",
		})
		entries = {
			entry(folder, { step = "unknown" }),
			entry(folder, { step = "plan", variant = "other" }),
			entry(folder, { step = "merge" }),
			flat,
			entry(other, { step = "merge" }),
		}
		local cmd, cwd = triggered()
		assert(cmd == 'review "' .. vim.fs.joinpath(folder, "flat.implementation.md") .. '"' and cwd == fork, cmd .. " " .. cwd)
		table.remove(entries, 4)
		cmd, cwd = triggered()
		assert(cmd == "merge" and cwd == main, cmd .. " " .. cwd)
		table.insert(entries, 1, entry(folder, { step = "plan", variant = "slow" }))
		cmd, cwd = triggered()
		assert(cmd == "plan slow" and cwd == fork, cmd .. " " .. cwd)
		entries[1] = entry(folder, { step = "plan" })
		cmd, cwd = triggered()
		assert(cmd == "plan fast" and cwd == fork, cmd .. " " .. cwd)
		write("plan.md")
		cmd = triggered()
		assert(cmd == "merge", cmd)
		entries = {}
		auto.trigger_next()
		assert(notifications[#notifications].message == "No auto task")
	]])
end

return T
