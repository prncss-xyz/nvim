local M = { base = "HEAD" }

function M.open(base, dir)
	require("my.ui_toggle").activate("neotree", function()
		local cwd = dir or vim.fn.getcwd()
		local selected_base = base
		vim.fn.system({ "git", "-C", cwd, "rev-parse", "--verify", base .. "^{commit}" })
		if vim.v.shell_error ~= 0 then
			selected_base = "HEAD"
		end
		require("neo-tree.command").execute({ source = "git_status", dir = cwd, git_base = selected_base })
		require("my.git_base").set(cwd, selected_base)
		M.base = selected_base
	end)
end

return M
