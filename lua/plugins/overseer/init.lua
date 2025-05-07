local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local reverse = require("my.parameters").reverse
local theme = require("my.parameters").theme

return {
	{
		"stevearc/overseer.nvim",
		opts = {
			strategy = {
				"toggleterm",
				open_on_start = true,
			},
			templates = {
				"builtin",
				"my.zsh",
				"my.zsh-current",
			},
		},
		cmd = {
			"OverseerOpen",
			"OverseerClose",
			"OverseerToggle",
			"OverseerSaveBundle",
			"OverseerLoadBundle",
			"OverseerDeleteBundle",
			"OverseerRunCmd",
			"OverseerRun",
			"OverseerInfo",
			"OverseerBuild",
			"OverseerQuickAction",
			"OverseerTaskAction",
			"OverseerClearCache",
		},
		keys = {
			{
				domain.win .. theme.run,
				"<cmd>OverseerRun<cr>",
				desc = "Overseer Run",
			},
			{
				domain.win .. reverse(theme.run),
				"<cmd>OverseerRun<cr>",
				desc = "Overseer Run Command",
			},
			{
				"ou",
				"<cmd>OverseerToggle<cr>",
				desc = "Overseer Toggle",
			},
		},
		cond = not_vscode,
	},
}
