local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

return {
	{
		"barreiroleo/ltex_extra.nvim",
		dependencies = { "neovim/nvim-lspconfig" },
		opts = {
			server_opts = {
				load_langs = { "en-US", "fr" },
				capabilities = require("plugins.lsp.utils").cmp_capabilities,
				flags = {
					debounce_text_changes = 10000,
					allow_incremental_sync = true,
				},
				settings = {
					ltex = {
						enabled = { "markdown" },
						language = "auto",
						additionalRules = {
							enablePickyRules = true,
						},
						disabledRules = {
							en = {
								"UPPERCASE_SENTENCE_START",
								"PUNCTUATION_PARAGRAPH_END",
							},
							fr = {
								"APOS_TYP",
								"FRENCH_WHITESPACE",
								"UPPERCASE_SENTENCE_START",
								"PUNCTUATION_PARAGRAPH_END",
							},
						},
					},
				},
			},
		},
		enabled = personal,
		cond = not_vscode,
		ft = { "markdown", "tex", "gitcommit", "text" },
	},
	{
		"zk-org/zk-nvim",
		ft = "markdown",
		name = "zk",
		opts = {
			lsp = {
				config = {
					cmd = { "zk", "lsp" },
					name = "zk",
				},
			},
			auto_attach = {
				enabled = true,
				filetypes = { "markdown" },
			},
		},
		cmd = {
			"ZkIndex",
			"ZkNew",
			"ZkNewFromTitleSelection",
			"ZkNewFromContentSelection",
			"ZkCd",
			"ZkNotes",
			"ZkBacklinks",
			"ZkLinks",
			"ZkMatch",
			"ZkTags",
		},
		enabled = false,
		cond = not_vscode,
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		opts = {},
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		ft = { "markdown", "Avante" },
		cmd = { "RenderMarkdown" },
		cond = not_vscode,
	},
}
