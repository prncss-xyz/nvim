local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["screen status events"] = MiniTest.new_set()

T["screen status events"]["update status on transitions regardless of visibility"] = function()
	child.lua([[local notifications = {}
		local send
		local visible = true
		local item = {
			key = "agent",
			display_name = "agent",
			dir = "/tmp",
			hash = "agent:/tmp:1",
		}

		package.loaded["plugins.toggleterm.terms.history"] = {
			create_history = function()
				return {
					insert = function() end,
					find = function() return nil end,
					purge = function() end,
					filter = function() return {} end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			create_term = function(_, callback)
				send = callback
				return { window = 1, focus = function() end }
			end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			on_status = function(instance)
				table.insert(notifications, instance.status)
			end,
		}
		package.loaded["plugins.toggleterm.terms.window"] = {
			is_in_view = function() return visible end,
		}
		package.loaded["plugins.toggleterm.terms.get_query_fn"] = {
			get_query_fn = function() return function() return true end end,
		}
		package.loaded["plugins.toggleterm.terms.utils"] = {
			compose_gt = function() return function() return false end end,
			gt_field = function() return function() return false end end,
			lt_field = function() return function() return false end end,
			max_of = function() return item end,
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return { item } end,
		}
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() return function() return "agent" end end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms").focus({})
		send({ type = "status", value = "working" })
		local visible_status = item.status
		send({ type = "status", value = "working" })
		visible = false
		send({ type = "status", value = "blocked" })
		send({ type = "status", value = "blocked" })

		result = {
			visible_status = visible_status,
			status = item.status,
			notifications = notifications,
		}
	]])

	assert.same({
		visible_status = "working",
		status = "blocked",
		notifications = { "blocked" },
	}, child.lua_get("result"))
end

return T
