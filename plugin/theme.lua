-- Persist last colorscheme
-- see lua/plugins/theming.lua

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	pattern = "*",
	callback = function()
		require("my.theme_utils").save_theme()
		vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
		vim.api.nvim_set_hl(0, "NonText", { bg = "none" })
	end,
})
