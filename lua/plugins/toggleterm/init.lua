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
			on_open = function(term)
				require("plugins.toggleterm.terms").on_open(term)
			end,
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
				"<cmd>TermSelect<cr>",
				desc = "Select Terminal",
			},
			{
				ai_insert.toggle,
				function()
					require("plugins.toggleterm.terms").toggle_last()
				end,
				desc = "Toggle Last Terminal",
				mode = { "n", "x", "i", "t" },
			},
			{
				"oi",
				function()
					require("plugins.toggleterm.ops").repl_op:call({}, {
						i = function()
							local lang = require("flies.utils.editor").get_lang_at_cursor()
							require("plugins.toggleterm.repl").toggle(lang)
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
							require("plugins.toggleterm.agents").toggle()
						end,
						c = function()
							require("plugins.toggleterm.agents").send_current_line()
						end,
						e = function()
							require("plugins.toggleterm.agents").send_current_file()
						end,
						p = function()
							require("plugins.toggleterm.prompts").prompt()
						end,
						s = function()
							require("plugins.toggleterm.agents").select_agent()
						end,
					})
				end,
				desc = "Toggle agent",
			},
			{
				"oe",
				function()
					require("plugins.toggleterm.terms").toggle_term("term_e")
				end,
				desc = "Toggle Terminal e",
			},
			{
				"or",
				function()
					require("plugins.toggleterm.terms").toggle_term("term_r")
				end,
				desc = "Toggle Terminal r",
			},
			{
				"ow",
				function()
					require("plugins.toggleterm.terms").toggle_term("dev")
				end,
				desc = "Toggle Terminal Dev",
			},
			{
				"oo",
				function()
					require("plugins.toggleterm.terms").toggle_term("current")
				end,
				desc = "Toggle Terminal Current file",
			},
			{
				"occ",
				function()
					require("plugins.toggleterm.terms").toggle_term("diff")
				end,
				desc = "Toggle Terminal Diff",
			},
		},
		cond = not_vscode,
	},
}
