local personal = require("my.conds").personal
local not_vscode = require("my.conds").not_vscode
local analyzers = vim.fn.stdpath("data") .. "/mason/share/sonarlint-analyzers/"

local ft = {
	"dockerfile",
	"javascript",
	"typescript",
	"javascriptreact",
	"typescriptreact",
}

return {
	"https://gitlab.com/schrieveslaach/sonarlint.nvim",
	opts = {
		server = {
			cmd = {
				"sonarlint-language-server",
				"-stdio",
				"-analyzers",
				analyzers .. "sonarjs.jar",
			},
		},
		filetypes = ft,
		cmd = "SonarlintListRules",
	},
	ft = ft,
	cond = not_vscode,
	enabled = false,
	-- enabled = personal,
}
