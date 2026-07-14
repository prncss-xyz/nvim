local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["idle notifications"] = MiniTest.new_set()

T["idle notifications"]["fire once until the terminal is focused again"] = function()
	child.lua([[local idle_count = 0
		local send
		local item = {
			key = "agent",
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
				return {
					focus = function() end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			on_idle = function()
				idle_count = idle_count + 1
			end,
		}
		package.loaded["plugins.toggleterm.terms.get_query_fn"] = {
			get_query_fn = function()
				return function() return true end
			end,
		}
		package.loaded["plugins.toggleterm.terms.utils"] = {
			compose_gt = function() return function() return false end end,
			gt_field = function() return function() return false end end,
			lt_field = function() return function() return false end end,
			max_of = function()
				return item
			end,
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function()
				return { item }
			end,
		}
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms").focus({})

		send({ type = "status", value = "active", seen = true })
		send({ type = "status", value = "idle", seen = false })
		send({ type = "status", value = "active", seen = false })
		send({ type = "status", value = "idle", seen = false })
		local before_focus = idle_count

		send({ type = "focus" })
		send({ type = "status", value = "active", seen = false })
		send({ type = "status", value = "idle", seen = false })
		local after_focus = idle_count

		send({ type = "status", value = "active", seen = true })
		send({ type = "status", value = "idle", seen = false })

		result = {
			before_focus = before_focus,
			after_focus = after_focus,
			after_seen = idle_count,
			status = item.status,
		}
	]])

	assert.same({ before_focus = 1, after_focus = 2, after_seen = 3, status = "idle" }, child.lua_get("result"))
end

return T
