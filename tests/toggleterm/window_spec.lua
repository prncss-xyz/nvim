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

T["uses the cwd symlink path for a resolved buffer"] = function()
	local result = child.lua_get([[(function()
		local base = vim.fn.tempname()
		local view = base .. "/view"
		local target = base .. "/shared/artifacts"
		vim.fn.mkdir(target .. "/feature", "p")
		vim.fn.mkdir(view, "p")
		vim.uv.fs_symlink(target, view .. "/.artifacts", { dir = true })
		vim.cmd.cd(vim.fn.fnameescape(view))
		vim.api.nvim_buf_set_name(0, target .. "/feature/spec.md")
		vim.b.my_rooter_symlink_cwd = view

		local path = require("plugins.toggleterm.terms.window").get_ctx().path
		vim.fn.delete(base, "rf")
		return path
	end)()]])

	assert.same(".artifacts/feature/spec.md", result)
end

return T
