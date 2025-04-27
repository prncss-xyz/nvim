local not_vscode = require("my.conds").not_vscode

return {
	{
		"calind/selenized.nvim",
		commit = "a43e34d",
		lazy = false, -- make sure we load this during startup if it is your main colorscheme
		priority = 1000, -- make sure to load this before all the other start plugins
		config = function()
			-- load the colorscheme here
			vim.o.background = "dark"
			vim.cmd.colorscheme("selenized")
		end,
		cond = not_vscode,
		enabled = true,
	},
	{
		"rebelot/kanagawa.nvim",
		enabled = true,
	},
	{
		"rose-pine/neovim",
		name = "rose-pine",
		enabled = true,
	},
	{
		"ellisonleao/gruvbox.nvim",
		enabled = true,
	},
	{
		"ishan9299/nvim-solarized-lua",
		enabled = true,
	},
}
