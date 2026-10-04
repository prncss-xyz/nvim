-- Persist the colorscheme selected for each zone.

vim.api.nvim_create_autocmd({ "ColorScheme" }, {
	pattern = "*",
	callback = function()
		local themes = require("my.theme_utils")
		themes.remember_current_theme(vim.g.colors_name)
	end,
})
