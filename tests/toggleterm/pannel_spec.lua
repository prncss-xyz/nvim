local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path]])
		end,
		post_once = child.stop,
	},
})

T["terminal pannel"] = MiniTest.new_set()

T["terminal pannel"]["toggles a filtered side pannel and focuses the selected terminal"] = function()
	child.lua([[
		local focused = {}
		local items = {
			{
				hash = "agent:one",
				key = "agent",
				instance_count = 1,
				display_name = "Agent one",
				dir = "/tmp/one",
				status = "working",
				term = { focus = function() table.insert(focused, "agent:one") end },
			},
			{
				hash = "shell:one",
				key = "shell",
				instance_count = 1,
				display_name = "Shell",
				dir = "/tmp/one",
				status = "idle",
				term = { focus = function() table.insert(focused, "shell:one") end },
			},
		}
		local listener
		local deps = {
			items = function(query)
				return vim.tbl_filter(require("plugins.toggleterm.terms.get_query_fn").get_query_fn(query), items)
			end,
			subscribe = function(cb)
				listener = cb
				return function() listener = nil end
			end,
			format = function(item) return item.status .. " " .. item.display_name end,
		}

		local pannel = require("plugins.toggleterm.terms.pannel")
		pannel.toggle({ key = "agent" }, deps)
		local win = vim.api.nvim_get_current_win()
		local buf = vim.api.nvim_win_get_buf(win)
		local opened = {
			filetype = vim.bo[buf].filetype,
			lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
			winfixwidth = vim.wo[win].winfixwidth,
		}
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		pannel.toggle({ key = "agent" }, deps)
		result = {
			opened = opened,
			focused = focused,
			closed = not vim.api.nvim_win_is_valid(win),
			unsubscribed = listener == nil,
		}
	]])

	assert.same({
		opened = {
			filetype = "toggleterm-pannel",
			lines = { "working Agent one" },
			winfixwidth = true,
		},
		focused = { "agent:one" },
		closed = true,
		unsubscribed = true,
	}, child.lua_get("result"))
end

T["terminal pannel"]["refreshes from events and preserves selection by hash"] = function()
	child.lua([[
		local items = {
			{ hash = "one", key = "agent", instance_count = 1, display_name = "One", status = "idle", term = { focus = function() end } },
			{ hash = "two", key = "agent", instance_count = 2, display_name = "Two", status = "working", term = { focus = function() end } },
		}
		local listener
		local deps = {
			items = function() return items end,
			subscribe = function(cb)
				listener = cb
				return function() listener = nil end
			end,
			format = function(item) return item.hash .. ":" .. item.status end,
		}
		local pannel = require("plugins.toggleterm.terms.pannel")
		pannel.toggle({}, deps)
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(win, { 2, 0 })
		items[2].status = "blocked"
		items = { items[2], items[1] }
		listener()
		vim.wait(100, function()
			return vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, 1, false)[1] == "two:blocked"
		end)
		result = {
			lines = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), 0, -1, false),
			cursor = vim.api.nvim_win_get_cursor(win),
		}
	]])

	assert.same({
		lines = { "two:blocked", "one:idle" },
		cursor = { 1, 0 },
	}, child.lua_get("result"))
end

T["terminal pannel"]["renders an empty state and enter is a no-op"] = function()
	child.lua([[
		local deps = {
			items = function() return {} end,
			subscribe = function() return function() end end,
			format = function() error("must not format") end,
		}
		local pannel = require("plugins.toggleterm.terms.pannel")
		pannel.toggle({}, deps)
		local buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	]])

	assert.same({ "No matching terminals" }, child.lua_get("result"))
end

return T
