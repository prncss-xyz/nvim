local not_vscode = require("my.conds").not_vscode

return {
	{
		"williamboman/mason.nvim",
		opts = {},
		cmd = {
			"Mason",
			"MasonUpdate",
			"MasonInstall",
			"MasonUninstall",
			"MasonUninstallAll",
			"MasonLog",
		},
		keys = {
			{
				"omm",
				"<cmd>Mason<cr>",
				desc = "Mason",
			},
		},
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			"williamboman/mason.nvim",
		},
		opts = {
			automatic_installation = true,
			automatic_enable = false,
		},
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
		},
		lazy = false,
	},
	{
		"zeioth/garbage-day.nvim",
		dependencies = "neovim/nvim-lspconfig",
		event = "VeryLazy",
		opts = {},
		enabled = false,
	},
	{
		"nvimtools/none-ls.nvim",
		opts = function(_, opts)
			local null_ls = require("null-ls")
			local github_comments = require("plugins.lsp.github_comments")

			opts.sources = {
				null_ls.builtins.code_actions.ts_node_action,
				null_ls.builtins.code_actions.gitsigns,
				null_ls.builtins.diagnostics.fish,
				null_ls.builtins.formatting.fish_indent,
				null_ls.builtins.formatting.shfmt,
				null_ls.builtins.formatting.stylua,
				null_ls.builtins.formatting.golines,
				null_ls.builtins.hover.dictionary,
			}
			vim.list_extend(opts.sources, github_comments.sources())
		end,
		event = "VeryLazy",
		cond = not_vscode,
	},
	{
		"b0o/schemastore.nvim",
		config = function()
			vim.lsp.config("jsonls", {
				capabilities = require("plugins.lualine").cmp_capabilities,
				settings = {
					json = {
						schemas = require("schemastore").json.schemas(),
						validate = { enabled = true },
					},
				},
			})
			vim.lsp.config("yamlls", {
				capabilities = require("plugins.lualine").cmp_capabilities,
				settings = {
					yaml = {
						schemaStore = {
							-- You must disable built-in schemaStore support if you want to use
							-- this plugin and its advanced options like `ignore`.
							enabled = false,
							-- Avoid TypeError: Cannot read properties of undefined (reading 'length')
							url = "",
						},
						schemas = require("schemastore").yaml.schemas(),
					},
				},
			})
			vim.lsp.enable({ "jsonls", "yamlls" })
		end,
		ft = { "json", "yaml" },
		cond = not_vscode,
	},
	{
		"folke/lazydev.nvim",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
				{ path = "${3rd}/busted/library", words = { "describe", "it" } },
			},
		},
		cond = not_vscode,
		ft = "lua",
		cmd = "LazyDev",
	},
}
