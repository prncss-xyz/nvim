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
		end)
		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "http://localhost:3000/abcdefghijklmnopqr" })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		local before = vim.deepcopy(events)
		vim.api.nvim_buf_set_lines(bufnr, 1, 1, false, { "stuvwxyz?key=value" })
		callbacks.on_lines(nil, bufnr, 0, 1, 1, 2)
		result = { before = before, after = events }
	]])
	assert.same({ before = {}, after = {
		{ type = "url", value = "http://localhost:3000/abcdefghijklmnopqrstuvwxyz?key=value" },
	} }, child.lua_get("result"))
end

return T
