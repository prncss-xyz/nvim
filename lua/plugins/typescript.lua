local not_vscode = require("my.conds").not_vscode

return {
	{
		"yioneko/nvim-vtsls",
		config = function()
			require("lspconfig.configs").vtsls = require("vtsls").lspconfig
			-- FIXME: this causes a warning without apparent problems
			require("lspconfig").vtsls.setup({
				on_attach = require("workspace-diagnostics").populate_workspace_diagnostics,
			})
		end,
		cmd = { "VtsExec", "VtsRename" },
		ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
		cond = not_vscode,
	},
	{
		"dmmulroy/ts-error-translator.nvim",
		dependencies = { "yioneko/nvim-vtsls" },
		opts = {},
		ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
		cond = not_vscode,
		enabled = false,
	},
	{
		"artemave/workspace-diagnostics.nvim",
	},
}
