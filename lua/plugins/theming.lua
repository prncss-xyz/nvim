local not_vscode = require("my.conds").not_vscode
local work = require("my.conds").work
local tui = require("my.conds").tui

local theme = require("my.theme_utils").load_theme()

local function colorscheme(name, config)
	config.cond = not_vscode
	if name == theme.colors_name then
		config.priority = 1000
		config.lazy = false
		config.dependencies = work({
			"f-person/auto-dark-mode.nvim",
		}, nil)
		function config.config()
			vim.o.background = theme.background
			vim.cmd.colorscheme(name)
		end
	end
	return config
end

return {
	colorscheme("matrix", {
		"iruzo/matrix-nvim",
		commit = "5fafe6b",
	}),
	colorscheme("selenized", {
		"calind/selenized.nvim",
		commit = "a43e34d",
	}),
	colorscheme("kanagawa", {
		"rebelot/kanagawa.nvim",
	}),
	colorscheme("rose-pine", {
		name = "rose-pine",
		"rose-pine/neovim",
	}),
	colorscheme("gruvbox", {
		"ellisonleao/gruvbox.nvim",
	}),
	colorscheme("solarized", {
		"ishan9299/nvim-solarized-lua",
		commit = "d69a263",
	}),
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
		cond = tui,
	},
	{
		"f-person/auto-dark-mode.nvim",
		commit = "c31de12",
		opts = {},
		enabled = false,
	},
}
