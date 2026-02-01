local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

return {
	{
		"barreiroleo/ltex_extra.nvim",
		dependencies = { "neovim/nvim-lspconfig" },
		enabled = personal,
		cond = not_vscode,
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
		cond = false,
	},
}
