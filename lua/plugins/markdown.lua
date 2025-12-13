local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

return {
	{
		"barreiroleo/ltex_extra.nvim",
		dependencies = { "neovim/nvim-lspconfig" },
		opts = {
			load_langs = { "en-US", "fr" },
			init_check = true,
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
