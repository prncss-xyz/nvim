local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local edit = domain.edit
local win = domain.win
local theme = require("my.parameters").theme

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
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = {
			"williamboman/mason.nvim",
		},
		opts = {
			automatic_installation = true,
		},
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason-lspconfig.nvim",
		},
		config = function()
			for _, lsp in ipairs({
				"bashls",
				"graphql",
				"gopls",
				"eslint",
			}) do
				require("lspconfig")[lsp].setup({
					capabilities = require("plugins.lsp.utils").cmp_capabilities,
				})
			end
			require("lspconfig").lua_ls.setup({
				capabilities = require("plugins.lualine").cmp_capabilities,
				on_attach = function(client, bufnr)
					require("workspace-diagnostics").populate_workspace_diagnostics(client, bufnr)
				end,
				settings = {
					Lua = {
						telemetry = {
							enabled = false,
						},
					},
				},
			})
		end,
		init = function()
			vim.diagnostic.config({ virtual_text = false, update_in_insert = true })
		end,
		keys = {
			{
				"<c-s>",
				mode = { "n", "i" },
				function()
					vim.cmd("stopinsert")
					vim.lsp.buf.format({
						async = false,
						filter = function(client)
							return not vim.tbl_contains({
								"lua_ls",
								"vtsls",
							}, client.name)
						end,
					})
				end,
				desc = "LSP Format",
			},
			{
				edit .. theme.symbol,
				function()
					vim.lsp.buf.rename()
				end,
				desc = "LSP Rename",
			},
			{
				edit .. edit,
				mode = { "n", "x" },
				function()
					vim.lsp.buf.code_action()
				end,
				desc = "LSP Code Action",
			},
			{
				win .. theme.definition,
				function()
					vim.lsp.buf.hover()
				end,
				desc = "LSP Hover",
			},
		},
		cmd = { "LspInfo" },
		event = "BufReadPost",
		cond = not_vscode,
	},
	{
		"zeioth/garbage-day.nvim",
		dependencies = "neovim/nvim-lspconfig",
		event = "VeryLazy",
		opts = {},
		enabled = false,
	},
	{
		"jay-babu/mason-null-ls.nvim",
		commit = "de19726",
		dependencies = {
			"williamboman/mason.nvim",
		},
		opts = {
			automatic_installation = true,
		},
	},
	{
		"nvimtools/none-ls.nvim",
		dependencies = {
			"jay-babu/mason-null-ls.nvim",
		},
		opts = function(_, opts)
			local null_ls = require("null-ls")
			opts.sources = {
				null_ls.builtins.code_actions.gitsigns,
				null_ls.builtins.code_actions.refactoring,
				null_ls.builtins.diagnostics.yamllint,
				null_ls.builtins.diagnostics.zsh,
				null_ls.builtins.formatting.shfmt,
				null_ls.builtins.formatting.stylua,
				null_ls.builtins.formatting.prettierd,
				null_ls.builtins.formatting.golines,
				-- TODO: fourmolu
			}
		end,
		event = "VeryLazy",
		cond = not_vscode,
	},
	{
		"b0o/schemastore.nvim",
		config = function()
			require("lspconfig").jsonls.setup({
				capabilities = require("plugins.lualine").cmp_capabilities,
				settings = {
					json = {
						schemas = require("schemastore").json.schemas(),
						validate = { enabled = true },
					},
				},
			})
			require("lspconfig").yamlls.setup({
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
		end,
		ft = { "json", "yaml" },
		cond = not_vscode,
	},
	{
		"folke/lazydev.nvim",
		opts = {
			library = {
				{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			},
		},
		cond = not_vscode,
		ft = "lua",
		cmd = "LazyDev",
	},
}
