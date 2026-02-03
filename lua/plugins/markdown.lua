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
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			completions = { lsp = { enabled = true } },
			file_types = { "markdown", "mdx" },
			code = { enabled = false },
		},
		ft = { "markdown", "Avante", "mdx" },
		cmd = { "RenderMarkdown" },
	},
	{
		"obsidian-nvim/obsidian.nvim",
		version = "*", -- use latest release, remove to use latest commit
		ft = "markdown",
		---@module 'obsidian'
		---@type obsidian.config
		opts = {
			legacy_commands = false, -- this will be removed in the next major release
			workspaces = {
				{
					name = "notes",
					path = "~/projects/notes",
				},
			},
		},
    enabled = false,
	},
}
