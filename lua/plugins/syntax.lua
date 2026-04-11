local personal = require("my.conds").personal
local not_vscode = require("my.conds").not_vscode

return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		branch = "main",
		lazy = false,
		config = function()
			local ts = require("nvim-treesitter")

			local parsers = {
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

			local installed = ts.get_installed()
			local to_install = {}
			for _, parser in ipairs(parsers) do
				if not vim.list_contains(installed, parser) then
					table.insert(to_install, parser)
				end
			end
			if #to_install > 0 then
				ts.install(to_install)
			end

			vim.treesitter.language.register("markdown", "mdx")

			vim.api.nvim_create_autocmd("FileType", {
				callback = function(args)
					local ft = args.match
					local lang = vim.treesitter.language.get_lang(ft) or ft
					local ok = pcall(vim.treesitter.language.inspect, lang)
					if ok then
						vim.treesitter.start()
						vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
					end
				end,
			})
		end,
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
