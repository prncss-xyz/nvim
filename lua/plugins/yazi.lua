local not_vscode = require("my.conds").not_vscode
local reverse = require("my.parameters").reverse
local file = require("my.parameters").domain.file

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
				file .. "l",
				mode = { "n", "x" },
				"<cmd>Yazi toggle<cr>",
				desc = "Yazi Last",
			},
			{
				file .. "f",
				mode = { "n", "v" },
				"<cmd>Yazi<cr>",
				desc = "Yazi Reveal",
			},
			{
				file .. reverse("f"),
				"<cmd>Yazi cwd<cr>",
				desc = "Yazi Cwd",
			},
		},
		event = "VeryLazy",
		cond = not_vscode,
	},
}
