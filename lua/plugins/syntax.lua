local personal = require("my.conds").personal
local not_vscode = require("my.conds").not_vscode

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false,
		init = function()
			local ensureInstalled = {
				"gotmpl",
				"fish",
				"markdown",
				"markdown_inline",
				"bash",
				"css",
				"html",
				"javascript",
				"json",
				"lua",
				"tsx",
				"typescript",
				"yaml",
				"regex",
			}
			local alreadyInstalled = require("nvim-treesitter.config").get_installed()
			local parsersToInstall = vim.iter(ensureInstalled)
				:filter(function(parser)
					return not vim.tbl_contains(alreadyInstalled, parser)
				end)
				:totable()
			require("nvim-treesitter").install(parsersToInstall)

			vim.api.nvim_create_autocmd("FileType", {
				callback = function()
					-- Enable treesitter highlighting and disable regex syntax
					pcall(vim.treesitter.start)
					-- Enable treesitter-based indentation
					vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end,
			})
		end,
		config = {},
	},
	{
		"HiPhish/rainbow-delimiters.nvim",
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
		ft = "sway",
		cond = not_vscode,
		enabled = false and personal,
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
		"nvim-treesitter/nvim-treesitter-context",
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
		enabled = true,
	},
}
