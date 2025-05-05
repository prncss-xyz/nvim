local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

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
		commit = "d69a263",
		enabled = true,
	},
	{
		"iruzo/matrix-nvim",
		commit = "5fafe6b",
		enabled = true,
	},
	{
		"sphamba/smear-cursor.nvim",
		opts = false and {
			cursor_color = "#ff8800",
			stiffness = 0.3,
			trailing_stiffness = 0.1,
			trailing_exponent = 5,
			never_draw_over_target = true,
			hide_target_hack = true,
			gamma = 1,
		} or {},
		event = "VeryLazy",
		cond = not_vscode,
	},
	{
		"4e554c4c/darkman.nvim",
		event = "VimEnter",
		build = "go build -o bin/darkman.nvim",
		enabled = false and personal,
		cond = not_vscode,
	},
}
