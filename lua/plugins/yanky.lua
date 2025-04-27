local reverse = require("my.parameters").reverse
local edit = require("my.parameters").domain.edit
local pick = require("my.parameters").domain.pick

return {
	{
		"gbprod/yanky.nvim",
		dependencies = {
			"kkharji/sqlite.lua",
			"folke/snacks.nvim",
		},
		opts = {
			preserve_cursor_position = {
				enabled = true,
			},
			ring = {
				storage = "sqlite",
			},
			highlight = {
				timer = 200,
			},
			system_clipboard = {
				sync_with_ring = false,
			},
		},
		event = "BufReadPost",
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
				"<c-o><plug>(YankyPutBefore)",
				mode = { "i", "s", "c" },
				desc = "Paste Before",
			},
			{
				"<c-v>",
				"<plug>(YankyPutBefore)",
				mode = { "n", "x" },
				desc = "Paste Before",
			},
			{
				edit .. reverse("v"),
				"<plug>(YankyPutBefore)",
				mode = { "n", "x" },
				desc = "Paste Before",
			},
			{
				edit .. "v",
				"<plug>(YankyPutAfter)",
				mode = { "n", "x" },
				desc = "Paste After",
			},
		},
	},
}
