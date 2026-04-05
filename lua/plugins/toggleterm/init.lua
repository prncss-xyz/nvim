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
					require("plugins.toggleterm.op").repl_op:call({}, {
						i = function()
							local lang = require("flies.utils.editor").get_lang_at_cursor()
							local term = require("plugins.toggleterm.terms").from_filetype(lang)
							if not term then
								return
							end
							require("plugins.toggleterm.terms").term(term):toggle()
						end,
					})
				end,
				desc = "Toggle REPL",
			},
			{
				ai,
				function()
					require("plugins.toggleterm.op").agent_op:call({}, {
						a = function()
							require("plugins.toggleterm.terms").term("agent"):toggle()
						end,
						c = function()
							require("plugins.toggleterm.terms").send_lines(
								"agent",
								{ require("plugins.toggleterm.agent").current_position_ref() }
							)
						end,
						e = function()
							require("plugins.toggleterm.terms").send_lines(
								"agent",
								{ require("plugins.toggleterm.agent").current_file_ref() }
							)
						end,
					})
				end,
				desc = "Toggle agent",
			},
			{
				"oe",
				function()
					require("plugins.toggleterm.terms").term("term_e"):toggle()
				end,
				desc = "Toggle Terminal e",
			},
			{
				"or",
				function()
					require("plugins.toggleterm.terms").term("term_r"):toggle()
				end,
				desc = "Toggle Terminal r",
			},
			{
				"opw",
				function()
					require("plugins.toggleterm.terms").term("dev"):spawn({
						close_on_exit = false,
					})
				end,
				desc = "Spawn Terminal Dev",
			},
			{
				"ow",
				function()
					require("plugins.toggleterm.terms").term("dev"):toggle()
				end,
				desc = "Toggle Terminal Dev",
			},
			{
				"olm",
				function()
					require("plugins.toggleterm.terms").term("mocks"):toggle()
				end,
				desc = "Toggle Terminal Mocks",
			},
			{
				"ols",
				function()
					require("plugins.toggleterm.terms").term("dev"):spawn({
						close_on_exit = false,
					})
					require("plugins.toggleterm.terms").term("mocks"):spawn({
						close_on_exit = false,
					})
				end,
				desc = "Spawn Dev",
			},
			{
				"oo",
				function()
					require("plugins.toggleterm.terms").term("term_o"):toggle()
				end,
				desc = "Toggle Terminal Current file",
			},
			{
				"occ",
				function()
					require("plugins.toggleterm.terms").term("diff"):toggle()
				end,
				desc = "Toggle Terminal Diff",
			},
		},
		cond = not_vscode,
	},
}
