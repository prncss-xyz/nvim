local not_vscode = require("my.conds").not_vscode
local work = require("my.conds").work
local tui = require("my.conds").tui
local domain = require("my.parameters").domain

local theme = require("my.theme_utils").load_theme()

local function find(value, tbl)
	if type(tbl) == "string" then
		return tbl == value
	end
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

local function colorscheme(names, config)
	config.cond = not_vscode
	if find(theme.colors_name, names) then
		config.priority = 1000
		config.lazy = false
		config.dependencies = work({
			"f-person/auto-dark-mode.nvim",
		}, nil)
		function config.config()
			vim.o.background = theme.background
			vim.cmd.colorscheme(theme.colors_name)
		end
	end
	return config
end

return {
	colorscheme({ "cyberdream", "cyberdream-light" }, {
		"scottmckendry/cyberdream.nvim",
	}),
	colorscheme({ "lackluster", "lackluster-dark", "lackluster-mint", "lackluster-light", "lackluster-night" }, {
		"slugbyte/lackluster.nvim",
		commit = "b247a6f",
	}),
	colorscheme("e-ink", {
		"e-ink-colorscheme/e-ink.nvim",
		commit = "c90bf52",
	}),
	colorscheme("matrix", {
		"iruzo/matrix-nvim",
		commit = "5fafe6b",
	}),
	colorscheme("selenized", {
		"calind/selenized.nvim",
		commit = "a43e34d",
	}),
	colorscheme({ "kanagawa", "kanagawa-lotus", "kanagawa-dragon", "kanagawa-wave" }, {
		"rebelot/kanagawa.nvim",
	}),
	colorscheme({ "rose-pine", "rose-pine-dawn", "rose-pine-main", "rose-pine-moon" }, {
		name = "rose-pine",
		"rose-pine/neovim",
	}),
	colorscheme("gruvbox", {
		"ellisonleao/gruvbox.nvim",
	}),
	colorscheme({ "solarized", "solarized-flat", "solarized-high", "solarized-low" }, {
		"ishan9299/nvim-solarized-lua",
		commit = "d69a263",
	}),
	{
		"xiyaowong/transparent.nvim",
		event = "ColorScheme",
		commit = "8ac5988",
		config = function()
			require("transparent").clear_prefix("lualine")
		end,
		keys = {
			{
				domain.appearance .. "o",
				function()
					vim.cmd("TransparentToggle")
				end,
				desc = "Toggle Transparent",
			},
		},
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
		"f-person/auto-dark-mode.nvim",
		commit = "c31de12",
		opts = {},
		enabled = false,
	},
}
