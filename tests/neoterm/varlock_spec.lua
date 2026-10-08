local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. package.path
				package.loaded["neoterm.proxy_schema"] = { ensure = function() end }
				callbacks, completed, starts = {}, {}, 0
				vim.system = function(_, _, cb)
					table.insert(callbacks, cb)
					return { wait = function() error("Blocking status check") end }
				end
				vim.wait = function() error("Blocking wait") end
				vim.fn.jobstart = function() starts = starts + 1; return 42 end
				vim.fn.jobwait = function() return { -1 } end
				middleware = require("neoterm.middlewares.varlock")
				function request()
					return middleware({ varlock = "/schema.env", cmd = { "echo", "hello" } }, function(opts, err)
						table.insert(completed, { opts = opts, err = err })
					end)
				end
				function respond(sessions)
					table.remove(callbacks, 1)({ code = 0, stdout = vim.json.encode(sessions) })
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["startup returns immediately and shares pending requests"] = function()
	child.lua([[request(); request()]])
	assert.same(1, child.lua_get("#callbacks"))
	assert.same(0, child.lua_get("#completed"))
	child.lua([[respond({})]])
	child.lua([[vim.schedule(function() end)]])
	assert.same(1, child.lua_get("starts"))
	child.lua([[
		local dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "neoterm", "varlock", vim.fn.sha256("/schema.env"))
		respond({ { cwd = dir, entryPaths = { dir .. "/schema.env" }, id = "session", env = { NODE_EXTRA_CA_CERTS = "/cert" } } })
	]])
	assert.same(2, child.lua_get("#completed"))
	assert.same(
		{ "varlock", "proxy", "run", "--session", "session", "--inject", "vars", "--", "echo", "hello" },
		child.lua_get("completed[1].opts.cmd")
	)
end

T["startup failure reaches all waiting requests"] = function()
	child.lua([[vim.fn.jobstart = function() return -1 end; request(); request(); respond({})]])
	assert.same(2, child.lua_get("#completed"))
	assert.same("Failed to start the varlock proxy for /schema.env", child.lua_get("completed[1].err"))
	assert.same(child.lua_get("completed[1].err"), child.lua_get("completed[2].err"))
end

return T
