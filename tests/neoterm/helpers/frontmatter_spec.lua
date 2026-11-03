local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. package.path
				frontmatter = require("neoterm.helpers.frontmatter")
			]])
		end,
		post_once = child.stop,
	},
})

T["is_task_file accepts task files"] = function()
	MiniTest.expect.equality(
		child.lua_get([[{
			frontmatter.is_task_file("/a/task.md"),
			frontmatter.is_task_file("/a/branch.task.md"),
			frontmatter.is_task_file("/a/plan.md"),
			frontmatter.is_task_file("/a/.task.md"),
			frontmatter.is_task_file("/a/task.md.bak"),
		}]]),
		{ true, true, false, false, false }
	)
end

T["update_status rejects non-task files"] = function()
	child.lua([[vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. "/plan.md")]])
	MiniTest.expect.error(function()
		child.lua("frontmatter.update_status()")
	end, "Not a task file")
end

T["add_dependency rejects non-task files"] = function()
	child.lua([[vim.api.nvim_buf_set_name(0, vim.fn.tempname() .. "/plan.md")]])
	MiniTest.expect.error(function()
		child.lua("frontmatter.add_dependency()")
	end, "Not a task file")
end

return T
