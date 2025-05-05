local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal
local tui = require("my.conds").tui

local current = "gruvbox"
local background = "dark"

local function colorscheme(name)
	return function(config)
		config.cond = not_vscode
		if name == current then
			config.priority = 1000
			config.lazy = false
			function config.config()
				vim.o.background = background
				vim.cmd.colorscheme(name)
			end
		end
		return config
	end
end

return {
	colorscheme("matrix")({
		"iruzo/matrix-nvim",
		commit = "5fafe6b",
	}),
	colorscheme("selenized")({
		"calind/selenized.nvim",
		commit = "a43e34d",
	}),
	colorscheme("kanagawa")({
		"rebelot/kanagawa.nvim",
	}),
	colorscheme("rose-pine")({
		"rose-pine/neovim",
	}),
	colorscheme("gruvbox")({
		"ellisonleao/gruvbox.nvim",
	}),
	colorscheme("solarized")({
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
		"4e554c4c/darkman.nvim",
		event = "VimEnter",
		build = "go build -o bin/darkman.nvim",
		enabled = false and personal,
		cond = not_vscode,
	},
}
