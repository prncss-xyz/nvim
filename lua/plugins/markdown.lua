local not_vscode = require("my.conds").not_vscode
local language = require("my.parameters").domain.language
local personal = require("my.conds").personal
local ft = { "markdown", "Avante", "mdx" }

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
		ft = ft,
		cond = not_vscode,
	},
	{
		"zk-org/zk-nvim",
		name = "zk",
		opts = {
			picker = "snacks_picker",
		},
		ft = ft,
		cond = not_vscode,
	},
	{
		"jmbuhr/otter.nvim",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		opts = {},
		keys = {
			{
				language .. "a",
				function()
					require("otter").activate()
				end,
				ft = ft,
				desc = "Toggle Otter",
			},
		},
		ft = ft,
		cond = not_vscode,
	},
	{
		"michaelb/sniprun",
		branch = "master",
		build = "sh install.sh 1",
		-- do 'sh install.sh 1' if you want to force compile locally
		-- (instead of fetching a binary from the github release). Requires Rust >= 1.65
		opts = {},
		cmd = { "SnipRun", "SnipInfo" },
		keys = {
			{
				language .. "<cr>",
				":%SnipRun<cr>",
				desc = "Run Current file (cumulative)",
			},
		},
	},
}
