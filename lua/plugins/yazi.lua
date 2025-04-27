local not_vscode = require("my.conds").not_vscode
local reverse = require("my.parameters").reverse
local theme = require("my.parameters").theme
local domain = require("my.parameters").domain
local pane = domain.pane

return {
	---@type LazySpec
	{
		"mikavilpas/yazi.nvim",
		dependencies = { "folke/snacks.nvim" },
		---@type YaziConfig | {}
		opts = {
			open_for_directories = true,
			keymaps = {
				show_help = "<f1>",
			},
		},
		init = function()
			vim.g.loaded_netrw = 1
			vim.g.loaded_netrwPlugin = 1
		end,
		keys = {
			{
				pane .. theme.file,
				mode = { "n", "v" },
				"<cmd>Yazi<cr>",
				desc = "Yazi Reveal",
			},
			{
				pane .. reverse(theme.file),
				"<cmd>Yazi cwd<cr>",
				desc = "Yazi Toggle",
			},
		},
		event = "VeryLazy",
		cond = not_vscode,
	},
}
