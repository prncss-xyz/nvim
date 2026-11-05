local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. package.path
				root = vim.fn.tempname()
				local projects = root .. "/projects"
				main = projects .. "/sample/main"
				linked = projects .. "/sample/feature space"
				unrelated = projects .. "/sample/other"
				vim.fn.mkdir(root .. "/artifacts", "p")
				vim.fn.mkdir(main .. "/.git/worktrees/feature", "p")
				vim.fn.mkdir(main .. "/src", "p")
				vim.fn.mkdir(linked, "p")
				vim.fn.mkdir(unrelated .. "/.git", "p")
				vim.fn.writefile({ "gitdir: " .. main .. "/.git/worktrees/feature" }, linked .. "/.git")
				vim.fn.writefile({ "../.." }, main .. "/.git/worktrees/feature/commondir")
				package.loaded["neoterm.config"] = {
					dirs = { projects = projects, artifacts = root .. "/artifacts" },
					tasks = { default_status = "ready", status = { { name = "ready" } } },
				}
				Snacks = { picker = { pick = function(opts) picker_opts = opts end } }
				tasks = require("neoterm.terms.artifacts.tasks")
				pickers = require("neoterm.pickers.projects")
				function ready()
					assert(vim.wait(3000, function() return tasks.projects() ~= nil end, 20))
				end
				function pick(worktrees)
					if worktrees then pickers.pick_worktree() else pickers.pick_project() end
					return picker_opts.finder({}, {})
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["warm pickers use the shared index without filesystem scans or processes"] = function()
	child.lua([[
		ready()
		vim.cmd.tcd(main .. "/src")
		local system, scandir, stat = vim.fn.system, vim.uv.fs_scandir, vim.uv.fs_stat
		local function unexpected() error("Picker performed IO") end
		vim.fn.system, vim.uv.fs_scandir, vim.uv.fs_stat = unexpected, unexpected, unexpected
		local projects = pick(false)
		local worktrees = pick(true)
		vim.fn.system, vim.uv.fs_scandir, vim.uv.fs_stat = system, scandir, stat
		assert(vim.deep_equal(projects, {
			{ text = linked, file = linked, dir = true },
			{ text = main, file = main, dir = true },
			{ text = unrelated, file = unrelated, dir = true },
		}), vim.inspect(projects))
		assert(vim.deep_equal(worktrees, { { text = linked, file = linked, dir = true } }), vim.inspect(worktrees))
		vim.cmd.tcd(linked)
		assert(pick(true)[1].file == main)
		vim.cmd.tcd(root)
		assert(#pick(true) == 0)
	]])
end

T["cold picker waits for the first shared scan and removes its listener"] = function()
	child.lua([[
		pickers.pick_project()
		local callbacks, items = {}, {}
		local async = {}
		local thread
		function async:on(event, callback) callbacks[event] = callback end
		function async:suspend() coroutine.yield() end
		function async:resume()
			assert(coroutine.resume(thread))
		end
		local finder = picker_opts.finder({}, { async = async })
		assert(type(finder) == "function")
		local subscribe = tasks.subscribe
		local listeners = 0
		tasks.subscribe = function(callback)
			listeners = listeners + 1
			local unsubscribe = subscribe(callback)
			return function()
				unsubscribe()
				listeners = listeners - 1
			end
		end
		thread = coroutine.create(function() finder(function(item) table.insert(items, item) end) end)
		assert(coroutine.resume(thread))
		assert(listeners == 1)
		assert(vim.wait(3000, function() return coroutine.status(thread) == "dead" end, 20))
		assert(#items == 3)
		assert(listeners == 0)
	]])
end

T["picker finds checkout changes maintained by the task watcher"] = function()
	child.lua([[
		ready()
		vim.fn.delete(linked, "rf")
		assert(vim.wait(3000, function() return #tasks.projects().checkouts == 2 end, 20))
		assert(#pick(false) == 2)
		vim.cmd.tcd(main)
		assert(#pick(true) == 0)
	]])
end

return T
