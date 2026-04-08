if not require("my.conds").not_vscode() then
	return
end

local group = vim.api.nvim_create_augroup("MyRooter", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter" }, {
	group = group,
	nested = true,
	callback = function()
		if vim.bo.buftype ~= "" then
			return
		end
		local root = vim.fs.root(0, require("my.parameters").rooter_patterns)
		if root then
			vim.api.nvim_set_current_dir(root)
		end
	end,
})

vim.api.nvim_create_autocmd({ "User" }, {
	group = group,
	pattern = "VeryLazy",
	callback = function()
		require("plugins.toggleterm.terms").setup_start()
	end,
})
