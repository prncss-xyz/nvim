local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

return {
	{
		"dmmulroy/ts-error-translator.nvim",
		opts = {},
		ft = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
		cond = not_vscode,
		enabled = false and personal,
	},
}
