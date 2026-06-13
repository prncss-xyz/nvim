local not_vscode = require("my.conds").not_vscode
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
		config.dependencies = { "f-person/auto-dark-mode.nvim" }
		function config.config()
			vim.cmd.colorscheme(theme.colors_name)
		end
	end
	return config
end

local builtin_colorschemes = {
	"habamax",
	"lunaperche",
	"quiet",
	"vim",
	"blue",
	"darkblue",
	"delek",
	"desert",
	"elflord",
	"evening",
	"industry",
	"koehler",
	"morning",
	"murphy",
	"pelf",
	"ron",
	"shine",
	"slate",
	"torte",
	"zellner",
}

if find(theme.colors_name, builtin_colorschemes) then
	vim.cmd.colorscheme(theme.colors_name)
end

return {
	colorscheme({ "catppuccin-nvim", "catppuccin-latte", "catppuccin-mocha", "catppuccin-frappe" }, {
		"catppuccin/nvim",
		name = "catppuccin",
		commit = "0303a7208dba448c459767486a38a6ec05c4216b",
	}),
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
			require("transparent").setup({
				exclude_groups = { "StatusLine", "StatusLineNC" },
			})
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
}
