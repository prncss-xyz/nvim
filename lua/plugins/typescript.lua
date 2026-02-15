local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal
local language = require("my.parameters").domain.language

local ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" }

return {
	{
		"yioneko/nvim-vtsls",
		config = function()
			vim.lsp.config("vtsls", {
				settings = {
					typescript = {
						inlayHints = {
							parameterNames = { enabled = "all" },
							parameterTypes = { enabled = true },
							variableTypes = { enabled = true },
							propertyDeclarationTypes = { enabled = true },
							functionLikeReturnTypes = { enabled = true },
							enumMemberValues = { enabled = true },
						},
					},
				},
			})
			vim.lsp.enable("vtsls", require("vtsls").config)
		end,
		keys = {
			{
				language .. "r",
				function()
					require("vtsls").commands.restart_tsserver()
				end,
				ft = ft,
				desc = "TS Restart TSServer",
			},
			{
				language .. "d",
				function()
					require("vtsls").commands.goto_source_definition()
				end,
				ft = ft,
				desc = "TS Goto Source Definition",
			},
			{
				language .. "f",
				function()
					require("vtsls").commands.fix_all()
				end,
				ft = ft,
				desc = "TS Fix All",
			},
			{
				language .. "x",
				function()
					require("vtsls").commands.remove_unused()
				end,
				ft = ft,
				desc = "TS Remove Unused",
			},
			{
				language .. "a",
				function()
					require("vtsls").commands.add_missing_imports()
				end,
				ft = ft,
				desc = "TS Add Missing Imports",
			},
			{
				language .. "l",
				function()
					require("vtsls").commands.source_actions()
				end,
				ft = ft,
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
}
