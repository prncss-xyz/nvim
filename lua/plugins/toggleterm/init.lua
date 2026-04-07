local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local theme = require("my.parameters").theme
local ai = domain.ai
local ai_insert = require("my.parameters").ai_insert

return {
	{
		"akinsho/toggleterm.nvim",
		opts = {
			direction = "vertical",
			size = 80,
		},
		cmd = {
			"ToggleTerm",
			"ToggleTermToggleAll",
			"TermExec",
			"TermSelect",
			"ToggleTermSetName",
		},
		keys = {
			{
				domain.pick .. theme.run,
				function()
					require("plugins.toggleterm.terms").select_term()
				end,
				desc = "Select Terminal",
			},
			{
				ai_insert.toggle,
				function()
					require("plugins.toggleterm.terms").toggle_last_term()
				end,
				desc = "Toggle Last Terminal",
				mode = { "n", "x", "i", "t" },
			},
			{
				"oi",
				function()
					require("plugins.toggleterm.ops").repl_op:call({}, {
						i = function()
							require("plugins.toggleterm.terms").focus_term("repl")
						end,
					})
				end,
				desc = "Toggle REPL",
			},
			{
				ai,
				function()
					require("plugins.toggleterm.ops").agent_op:call({}, {
						a = function()
							require("plugins.toggleterm.terms").focus_term("agent")
						end,
						c = function()
							require("plugins.toggleterm.agents").send_current_position()
						end,
						e = function()
							require("plugins.toggleterm.agents").send_current_file()
						end,
						p = function()
							require("plugins.toggleterm.agents").prompt()
						end,
					})
				end,
				desc = "Toggle agent",
			},
			{
				"oe",
				function()
					require("plugins.toggleterm.terms").focus_term("term_e")
				end,
				desc = "Toggle Terminal e",
			},
			{
				"or",
				function()
					require("plugins.toggleterm.terms").focus_term("term_r")
				end,
				desc = "Toggle Terminal r",
			},
			{
				"ow",
				function()
					require("plugins.toggleterm.terms").select_command()
				end,
				desc = "Toggle Terminal Dev",
			},
			{
				"oo",
				function()
					require("plugins.toggleterm.terms").focus_term("diff")
				end,
				desc = "Toggle Terminal Diff",
			},
		},
		cond = not_vscode,
	},
}
