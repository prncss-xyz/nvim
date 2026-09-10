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
		package.loaded["plugins.toggleterm.terms.window"] = { is_in_view = function() return visible end }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "❯ " })
		require("plugins.toggleterm.terms.attach_term").attach_term({ bufnr = bufnr, window = 1 }, function(event)
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

T["attach terminal"]["checks status during continuous output"] = function()
	child.lua([[local events = {}
		local callbacks
		local original_attach = vim.api.nvim_buf_attach
		vim.api.nvim_buf_attach = function(_, _, opts)
			callbacks = opts
			return true
		end
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "❯ " })
		require("plugins.toggleterm.terms.attach_term").attach_term({ bufnr = bufnr }, function(event)
			table.insert(events, event)
		end, {
			debounce_ms = 30,
			default_status = "idle",
			rules = {
				{ status = "working", contains = { "Working..." } },
			},
		})
		vim.wait(50, function() return #events == 1 end)

		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Working..." })
		for _ = 1, 5 do
			callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
			vim.wait(10)
		end
		vim.api.nvim_buf_attach = original_attach
		result = events
	]])

	assert.same({
		{ type = "status", value = "idle", visible = false },
		{ type = "status", value = "working", visible = false },
	}, child.lua_get("result"))
end

T["attach terminal"]["confirms plain idle without continuous terminal output"] = function()
	child.lua([[local events = {}
		local callbacks
		local original_attach = vim.api.nvim_buf_attach
		vim.api.nvim_buf_attach = function(_, _, opts)
			callbacks = opts
			return true
		end
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Working..." })
		require("plugins.toggleterm.terms.attach_term").attach_term({ bufnr = bufnr }, function(event)
			table.insert(events, event)
		end, {
			debounce_ms = 0,
			idle_confirmation_ms = 20,
			idle_confirmations = 2,
			idle_confirmation_cap_ms = 100,
			default_status = "idle",
			rules = {
				{ status = "working", contains = { "Working..." } },
			},
		})
		vim.wait(20, function() return #events == 1 end)

		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "redrawing" })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(10)
		local held_events = vim.deepcopy(events)
		vim.wait(100, function() return #events == 2 end)
		vim.api.nvim_buf_attach = original_attach
		result = { held_events = held_events, events = events }
	]])

	assert.same({
		held_events = {
			{ type = "status", value = "working", visible = false },
		},
		events = {
			{ type = "status", value = "working", visible = false },
			{ type = "status", value = "idle", visible = false },
		},
	}, child.lua_get("result"))
end

T["attach terminal"]["does not publish transient plain idle"] = function()
	child.lua([[local events = {}
		local callbacks
		local original_attach = vim.api.nvim_buf_attach
		vim.api.nvim_buf_attach = function(_, _, opts)
			callbacks = opts
			return true
		end
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Working..." })
		require("plugins.toggleterm.terms.attach_term").attach_term({ bufnr = bufnr }, function(event)
			table.insert(events, event)
		end, {
			debounce_ms = 0,
			idle_confirmation_ms = 20,
			idle_confirmations = 2,
			default_status = "idle",
			rules = {
				{ status = "working", contains = { "Working..." } },
			},
		})
		vim.wait(20, function() return #events == 1 end)

		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "redrawing" })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(10)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Working..." })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(80)
		vim.api.nvim_buf_attach = original_attach
		result = events
	]])

	assert.same({
		{ type = "status", value = "working", visible = false },
	}, child.lua_get("result"))
end

T["attach terminal"]["visible idle bypasses confirmation"] = function()
	child.lua([[local events = {}
		local callbacks
		local original_attach = vim.api.nvim_buf_attach
		vim.api.nvim_buf_attach = function(_, _, opts)
			callbacks = opts
			return true
		end
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local bufnr = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Working..." })
		require("plugins.toggleterm.terms.attach_term").attach_term({ bufnr = bufnr }, function(event)
			table.insert(events, event)
		end, {
			debounce_ms = 0,
			idle_confirmation_ms = 100,
			default_status = "idle",
			rules = {
				{ status = "working", contains = { "Working..." } },
				{ status = "idle", contains = { "Ready" }, visible_idle = true },
			},
		})
		vim.wait(20, function() return #events == 1 end)

		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Ready" })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(20, function() return #events == 2 end)
		vim.api.nvim_buf_attach = original_attach
		result = events
	]])

	assert.same({
		{ type = "status", value = "working", visible = false },
		{ type = "status", value = "idle", visible = false },
	}, child.lua_get("result"))
end

T["attach terminal"]["emits every local URL match"] = function()
	child.lua([[local events = {}
		local callbacks
		local original_attach = vim.api.nvim_buf_attach
		vim.api.nvim_buf_attach = function(_, _, opts)
			callbacks = opts
			return true
		end
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local bufnr = vim.api.nvim_create_buf(false, true)
		require("plugins.toggleterm.terms.attach_term").attach_term({ bufnr = bufnr }, function(event)
			table.insert(events, event)
		end)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
			"Local: http://localhost:3000 Network: http://127.0.0.1:3001/docs",
			"Again: http://localhost:3000",
		})
		callbacks.on_lines(nil, bufnr, 0, 0, 0, 2)
		vim.api.nvim_buf_attach = original_attach
		result = events
	]])

	assert.same({
		{ type = "url", value = "http://localhost:3000" },
		{ type = "url", value = "http://127.0.0.1:3001/docs" },
		{ type = "url", value = "http://localhost:3000" },
	}, child.lua_get("result"))
end

return T
