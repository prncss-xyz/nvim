-- Persist last colorscheme
-- see lua/plugins/theming.lua

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	pattern = "*",
	callback = function()
		local themes = require("my.theme_utils")
		themes.save_theme()
		themes.remember_current_theme(vim.g.colors_name)
	end,
})
