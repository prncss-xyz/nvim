local personal = require("my.conds").personal
local not_vscode = require("my.conds").not_vscode

return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		opts = {
			ensure_installed = {
				"markdown",
				"markdown_inline",
				"bash",
				"css",
				"graphql",
				"html",
				"javascript",
				"json",
				"lua",
				"tsx",
				"typescript",
				"yaml",
				"regex",
			},
			indent = {
				enable = true,
			},
		},
		config = function(_, opts)
			require("nvim-treesitter.configs").setup(opts)
			vim.treesitter.language.register("markdown", "mdx")
		end,
	},
	{
		"HiPhish/rainbow-delimiters.nvim",
		commit = "55ad4fb",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		opts = function()
			local rainbow_delimiters = require("rainbow-delimiters")
			return {
				strategy = {
					[""] = rainbow_delimiters.strategy["global"],
					vim = rainbow_delimiters.strategy["local"],
				},
				query = {
					[""] = "rainbow-delimiters",
					lua = "rainbow-blocks",
					-- tsx = 'rainbow-delimiters-react',
				},
				highlight = {
					"RainbowDelimiterRed",
					"RainbowDelimiterYellow",
					"RainbowDelimiterBlue",
					"RainbowDelimiterOrange",
					"RainbowDelimiterGreen",
					"RainbowDelimiterViolet",
					"RainbowDelimiterCyan",
				},
			}
		end,
		config = function(_, opts)
			vim.g.rainbow_delimiters = opts
		end,
		enabled = personal,
		cond = not_vscode,
	},
	{
		"ajouellette/sway-vim-syntax",
		enabled = false,
		ft = "sway",
		cond = not_vscode,
		enabled = personal,
	},
	{
		"folke/todo-comments.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		event = "VeryLazy",
		opts = {
			keywords = {
				WAIT = { icon = "", color = "warning" },
				TODO = {
					icon = " ",
					color = "info",
					alt = {
						"BUILD",
						"CI",
						"DOCS",
						"FEAT",
						"REFACT",
						"STYLE",
						"TEST",
						"QUESTION",
					},
				},
			},
		},
		cmd = {
			"TodoTrouble",
		},
		cond = not_vscode,
	},
	{
		"nvim-treesitter/nvim-treesitter-context",
		commit = "ff1d12c",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		opts = {
			min_window_height = 30,
			max_lines = 5,
			--[[ multiline_threshold = 3,
      trim_scope = 'outer', ]]
		},
		cmd = {
			"TSContextEnable",
			"TSContextDisable",
			"TSContextToggle",
		},
		event = "VeryLazy",
		enabled = false,
		cond = not_vscode,
	},
  {
    'nvim-treesitter/nvim-treesitter-context',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      min_window_height = 30,
      max_lines = 5,
      --[[ multiline_threshold = 3,
      trim_scope = 'outer', ]]
    },
    cmd = {
      'TSContextEnable',
      'TSContextDisable',
      'TSContextToggle',
    },
    event = 'VeryLazy',
    enabled = true,
  },
}
