local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal
local language = require("my.parameters").domain.language

return {
	{
		"yioneko/nvim-vtsls",
		config = function()
			require("lspconfig.configs").vtsls = require("vtsls").lspconfig
			require("lspconfig").vtsls.setup({
				on_attach = require("workspace-diagnostics").populate_workspace_diagnostics,
			})
		end,
		keys = {
			{
				language .. "r",
				function()
					require("vtsls").commands.restart_tsserver()
				end,
				desc = "TS Restart TSServer",
			},
			{
				language .. "d",
				function()
					require("vtsls").commands.goto_source_definition()
				end,
				desc = "TS Goto Source Definition",
			},
			{
				language .. "f",
				function()
					require("vtsls").commands.fix_all()
				end,
				desc = "TS Fix All",
			},
			{
				language .. "x",
				function()
					require("vtsls").commands.remove_unused()
				end,
				desc = "TS Remove Unused",
			},
			{
				language .. "a",
				function()
					require("vtsls").commands.add_missing_imports()
				end,
				desc = "TS Add Missing Imports",
			},
			{
				language .. "l",
				function()
					require("vtsls").commands.source_actions()
				end,
				desc = "TS Source Actions",
			},
		},
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
		enabled = false and personal,
	},
	{
		"artemave/workspace-diagnostics.nvim",
	},
}
