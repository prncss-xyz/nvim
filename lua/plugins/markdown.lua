local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

return {
	{
		"barreiroleo/ltex_extra.nvim",
		branch = "dev",
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
		ft = { "markdown", "tex", "gitcommit", "text", "mdx" },
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		opts = {
			-- FIXME: not working
			completions = { lsp = { enabled = true } },
			file_types = { "markdown", "mdx" },
			-- FIXME: not working
			code = { enabled = true },
		},
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		ft = { "markdown", "Avante", "mdx" },
		cmd = { "RenderMarkdown" },
		cond = not_vscode,
	},
}
