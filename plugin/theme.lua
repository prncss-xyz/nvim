-- Persist last colorscheme
-- see lua/plugins/theming.lua

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	pattern = "*",
	callback = function()
		require("my.theme_utils").save_theme()
	end,
})
