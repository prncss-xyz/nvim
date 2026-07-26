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

T["terminal panel"] = MiniTest.new_set()

T["terminal panel"]["toggles a filtered side panel and focuses the selected terminal"] = function()
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
		local history = {
			filter = function(filter)
				return vim.tbl_filter(filter, items)
			end,
		}
		local function subscribe(cb)
			listener = cb
			return function() listener = nil end
		end
		package.loaded["plugins.toggleterm.config"] = { panel = { width = 24 } }
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() return function(item) return item.status .. " " .. item.display_name end end,
		}

		local panel = require("plugins.toggleterm.terms.panel")
		panel.toggle({ key = "agent" }, history, subscribe)
		local win = vim.api.nvim_get_current_win()
		local buf = vim.api.nvim_win_get_buf(win)
		local opened = {
			filetype = vim.bo[buf].filetype,
			lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false),
			winfixwidth = vim.wo[win].winfixwidth,
			width = vim.api.nvim_win_get_width(win),
		}
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		panel.toggle({ key = "agent" }, history, subscribe)
		local closed = not vim.api.nvim_win_is_valid(win)
		local unsubscribed = listener == nil
		panel.open(history, subscribe)
		result = {
			opened = opened,
			focused = focused,
			closed = closed,
			unsubscribed = unsubscribed,
			reopened_lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false),
		}
	]])

	assert.same({
		opened = {
			filetype = "toggleterm-panel",
			lines = { "working Agent one" },
			winfixwidth = true,
			width = 24,
		},
		focused = { "agent:one" },
		closed = true,
		unsubscribed = true,
		reopened_lines = { "working Agent one" },
	}, child.lua_get("result"))
end

T["terminal panel"]["refreshes from events and preserves selection by hash"] = function()
	child.lua([[
		local items = {
			{ hash = "one", key = "agent", instance_count = 1, display_name = "One", status = "idle", term = { focus = function() end } },
			{ hash = "two", key = "agent", instance_count = 2, display_name = "Two", status = "working", term = { focus = function() end } },
		}
		local listener
		local history = {
			filter = function() return items end,
		}
		local function subscribe(cb)
			listener = cb
			return function() listener = nil end
		end
		package.loaded["plugins.toggleterm.config"] = { panel = { width = 24 } }
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() return function(item) return item.hash .. ":" .. item.status end end,
		}
		local panel = require("plugins.toggleterm.terms.panel")
		panel.toggle({}, history, subscribe)
		local win = vim.api.nvim_get_current_win()
		vim.api.nvim_win_set_cursor(win, { 2, 0 })
		items[2].status = "blocked"
		items = { items[2], items[1] }
		listener({ type = "status" })
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

T["terminal panel"]["renders an empty state and enter is a no-op"] = function()
	child.lua([[
		local history = {
			filter = function() return {} end,
		}
		local function subscribe() return function() end end
		package.loaded["plugins.toggleterm.config"] = { panel = { width = 24 } }
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() return function() error("must not format") end end,
		}
		local panel = require("plugins.toggleterm.terms.panel")
		panel.toggle({}, history, subscribe)
		local buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_feedkeys(vim.keycode("<CR>"), "x", false)
		result = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	]])

	assert.same({ "No matching terminals" }, child.lua_get("result"))
end

return T
