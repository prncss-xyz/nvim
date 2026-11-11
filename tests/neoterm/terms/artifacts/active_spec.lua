local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua(
				[[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path]]
			)
		end,
		post_once = child.stop,
	},
})

T["a task stays active while any owner remains and counts once per project"] = function()
	child.lua([[
		local active = require("neoterm.terms.artifacts.active")
		local changes = 0
		active.subscribe(function() changes = changes + 1 end)
		local first, second, other = {}, {}, {}
		active.add("/a/task.md", "alpha", first)
		active.add("/a/task.md", "alpha", second)
		active.add("/b/task.md", "alpha", other)
		assert(active.has("/a/task.md") and active.projects().alpha == 2 and changes == 2)
		active.remove("/a/task.md", first)
		assert(active.has("/a/task.md") and changes == 2)
		active.remove("/a/task.md", second)
		assert(not active.has("/a/task.md") and active.projects().alpha == 1 and changes == 3)
		active.remove("/a/task.md", second)
		active.remove("/b/task.md", other)
		assert(active.projects().alpha == nil and changes == 4)
	]])
end

return T
