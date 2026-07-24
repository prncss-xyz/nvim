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

T["attach terminal"]["emits only screen status transitions"] = function()
	child.lua([[local events = {}
		local callbacks
		local original_attach = vim.api.nvim_buf_attach
		vim.api.nvim_buf_attach = function(_, _, opts)
			callbacks = opts
			return true
		end
		package.loaded["plugins.toggleterm.terms.window"] = { is_in_view = function() return true end }
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
			},
		})
		vim.wait(20, function() return #events == 1 end)

		vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "Working..." })
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(20, function() return #events == 2 end)
		callbacks.on_lines(nil, bufnr, 0, 0, 1, 1)
		vim.wait(20)
		vim.api.nvim_buf_attach = original_attach
		result = events
	]])

	assert.same({
		{ type = "status", value = "idle" },
		{ type = "status", value = "working" },
	}, child.lua_get("result"))
end

return T
