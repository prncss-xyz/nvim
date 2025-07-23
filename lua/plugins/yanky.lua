local reverse = require("my.parameters").reverse
local edit = require("my.parameters").domain.edit
local pick = require("my.parameters").domain.pick
local not_vscode = require("my.conds").not_vscode

return {
	{
		"gbprod/yanky.nvim",
		dependencies = {
			-- "kkharji/sqlite.lua",
			"folke/snacks.nvim",
		},
		opts = {
			preserve_cursor_position = {
				enabled = true,
			},
			ring = {
				storage = "shada",
				-- storage = "sqlite",
			},
			highlight = {
				timer = 200,
			},
			system_clipboard = {
				sync_with_ring = false,
			},
		},
		keys = {
			{
				pick .. "y",
				function()
					Snacks.picker.yanky()
				end,
				mode = { "n", "x" },
				desc = "Open Yank History",
			},
			{
				"<c-p>",
				"<plug>(YankyCycleForward)",
				desc = "Paste Cycle Forward",
			},
			{
				"<c-n>",
				"<plug>(YankyCycleBackward)",
				desc = "Paste Cycle Backward",
			},
			{
				"<c-v>",
				"<plug>(YankyPutBeforeFilter)",
				mode = { "n", "x" },
				desc = "Paste Before",
			},
			{
				edit .. reverse("v"),
				-- "P",
				"<plug>(YankyPutBeforeFilter)",
				mode = { "n", "x" },
				desc = "Paste Before",
			},
			{
				edit .. "v",
				--  "p",
				"<plug>(YankyPutAfterFilter)",
				mode = { "n", "x" },
				desc = "Paste After",
			},
		},
		event = "BufReadPost",
		cond = not_vscode,
	},
}
