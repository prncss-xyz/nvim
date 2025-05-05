local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal
local tui = require("my.conds").tui

local function active(name, flag)
	return function(config)
		config.cond = not_vscode
		if flag or flag == nil then
			config.priority = 1000
			config.lazy = false
			function config.config()
				vim.o.background = "dark"
				vim.cmd.colorscheme(name)
			end
		end
		return config
	end
end

return {
	active("matrix")({
		"iruzo/matrix-nvim",
	}),
	{
		"calind/selenized.nvim",
		commit = "a43e34d",
	},
	{
		"rebelot/kanagawa.nvim",
	},
	{
		"rose-pine/neovim",
	},
	{
		"ellisonleao/gruvbox.nvim",
	},
	{
		"ishan9299/nvim-solarized-lua",
		commit = "d69a263",
	},
	{
		"iruzo/matrix-nvim",
		commit = "5fafe6b",
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
