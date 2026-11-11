local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["attach terminal"] = MiniTest.new_set()

T["attach terminal"]["emits status transitions with their visibility"] = function()
	child.lua([[local events = {}
		local callbacks
		local visible = true
		local original_attach = vim.api.nvim_buf_attach
		vim.api.nvim_buf_attach = function(_, _, opts)
			callbacks = opts
			return true
		end
		package.loaded["neoterm.terms.window"] = { is_in_view = function() return visible end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "❯ " })
		require("neoterm.terms.attach_term").attach_term({ bufnr = bufnr, window = 1 }, function(event)
			table.insert(events, event)
		end, {
			debounce_ms = 0,
			default_status = "idle",
			rules = {
				{ status = "working", contains = { "Working..." } },
				{ status = "idle", contains = { "❯" }, visible_idle = true },
			},
		})
		vim.wait(20, function() return #events == 1 end)

		visible = false
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Working..." })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(20, function() return #events == 2 end)
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(20)

		visible = true
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "❯ " })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(20, function() return #events == 3 end)
		vim.api.nvim_buf_attach = original_attach
		result = events
	]])

	assert.same({
		{ type = "status", value = "idle", visible = true },
		{ type = "status", value = "working", visible = false },
		{ type = "status", value = "idle", visible = true },
	}, child.lua_get("result"))
end

T["attach terminal"]["joins a URL wrapped by terminal width"] = function()
	child.lua([[local events = {}
		local callbacks
		vim.api.nvim_buf_attach = function(_, _, opts)
			callbacks = opts
			return true
		end
		package.loaded["neoterm.terms.window"] = { is_in_view = function() return false end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		vim.o.columns = 40
		local bufnr = vim.api.nvim_create_buf(false, true)
		require("neoterm.terms.attach_term").attach_term({ bufnr = bufnr }, function(event)
			table.insert(events, event)
		end, nil, nil, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "http://localhost:3000/abcdefghijklmnopqr" })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(150)
		local before = vim.deepcopy(events)
		vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { "stuvwxyz?key=value" })
		callbacks.on_lines(nil, bufnr, 0, 1, 1, 2)
		assert(vim.wait(1000, function() return #events == 1 end))
		result = { before = before, after = events }
	]])
	assert.same({ before = {}, after = {
		{ type = "url", value = "http://localhost:3000/abcdefghijklmnopqrstuvwxyz?key=value" },
	} }, child.lua_get("result"))
end

T["URL scanning"] = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.lua([[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
				package.loaded["neoterm.terms.window"] = { is_in_view = function() return false end }
				events = {}
				bufnr = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "", "", "", "" })
				reset = require("neoterm.terms.attach_term").attach_term({ bufnr = bufnr }, function(event)
					table.insert(events, event)
				end, nil, nil, true)
			]])
		end,
	},
})

T["URL scanning"]["coalesces changes and tracks pending URLs when lines shift"] = function()
	child.lua([[vim.api.nvim_buf_set_lines(bufnr, 3, 4, false, { "http://localhost:3000/pending" })
		vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, { "http://localhost:4000/inserted", "" })
		before = vim.deepcopy(events)
		assert(vim.wait(1000, function() return #events >= 2 end))
	]])

	assert.same({}, child.lua_get("before"))
	assert.same({
		{ type = "url", value = "http://localhost:4000/inserted" },
		{ type = "url", value = "http://localhost:3000/pending" },
	}, child.lua_get("events"))
end

T["URL scanning"]["scans during continuous output and catches the final update"] = function()
	child.lua([[updates = 0
		vim.fn.timer_start(20, function(timer)
			updates = updates + 1
			vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "http://localhost:3000/" .. updates })
			if updates == 20 then vim.fn.timer_stop(timer) end
		end, { ["repeat"] = -1 })
		assert(vim.wait(2000, function() return #events > 0 end))
		first_scan_updates = updates
		assert(vim.wait(2000, function()
			return events[#events].value == "http://localhost:3000/20"
		end))
	]])

	assert(child.lua_get("first_scan_updates < 20"))
	assert(child.lua_get("#events < updates"))
	assert.same("http://localhost:3000/20", child.lua_get("events[#events].value"))
end

T["URL scanning"]["sends each URL once until reset"] = function()
	child.lua([[vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "http://localhost:3000/" })
		assert(vim.wait(1000, function() return #events == 1 end))
		vim.api.nvim_buf_set_lines(bufnr, 1, 2, false, { "http://localhost:3000/" })
		vim.wait(400)
		before_reset = #events
		reset()
		vim.api.nvim_buf_set_lines(bufnr, 2, 3, false, { "http://localhost:3000/" })
		assert(vim.wait(1000, function() return #events == 2 end))
	]])

	assert.same(1, child.lua_get("before_reset"))
	assert.same({
		{ type = "url", value = "http://localhost:3000/" },
		{ type = "url", value = "http://localhost:3000/" },
	}, child.lua_get("events"))
end

T["URL scanning"]["ignores URLs outside the changed lines"] = function()
	child.lua([[local lines = { "http://localhost:3000/old" }
		for index = 2, 50 do
			lines[index] = "line " .. index
		end
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		assert(vim.wait(1000, function() return #events == 1 end))
		reset()
		vim.api.nvim_buf_set_lines(bufnr, 40, 41, false, { "http://127.0.0.1:8080/new" })
		assert(vim.wait(1000, function() return #events == 2 end))
		vim.wait(400)
	]])

	assert.same({
		{ type = "url", value = "http://localhost:3000/old" },
		{ type = "url", value = "http://127.0.0.1:8080/new" },
	}, child.lua_get("events"))
end

T["URL scanning"]["detects remote URLs without trailing punctuation"] = function()
	child.lua([[vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {
			"see https://github.com/neovim/neovim/pull/1, then http://localhost:5173/.",
		})
		assert(vim.wait(1000, function() return #events == 2 end))
	]])

	assert.same({
		{ type = "url", value = "https://github.com/neovim/neovim/pull/1" },
		{ type = "url", value = "http://localhost:5173/" },
	}, child.lua_get("events"))
end

T["URL scanning"]["caps remote URLs but keeps local ones"] = function()
	child.lua([[local lines = {}
		for index = 1, 12 do
			lines[index] = "https://example.com/" .. index
		end
		lines[13] = "http://app.localhost:3000/"
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
		assert(vim.wait(1000, function() return #events == 11 end))
		vim.wait(400)
	]])

	local values = vim.tbl_map(function(event)
		return event.value
	end, child.lua_get("events"))
	assert.same(11, #values)
	assert.same("https://example.com/10", values[10])
	assert.same("http://app.localhost:3000/", values[11])
end

for _, action in ipairs({ "reset", "detach" }) do
	T["URL scanning"]["cancels pending scans on " .. action] = function()
		child.lua([[vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, { "http://localhost:3000/cancelled" })]])
		if action == "reset" then
			child.lua([[reset()]])
		else
			child.lua([[vim.api.nvim_buf_delete(bufnr, { force = true })]])
		end
		child.lua([[vim.wait(400)]])

		assert.same(action == "detach" and { { type = "detach" } } or {}, child.lua_get("events"))
	end
end

return T
