if not require("my.conds").not_vscode() then
	return
end

local group = vim.api.nvim_create_augroup("MyRoot", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TabEnter", "FocusGained" }, {
	group = group,
	callback = function()
		if vim.bo.buftype ~= "" then
			return
		end
		local root = vim.fs.root(0, { ".git", ".hg", ".svn" })
		if root then
			vim.schedule(function()
				vim.api.nvim_set_current_dir(root)
			end)
		end
	end,
})
