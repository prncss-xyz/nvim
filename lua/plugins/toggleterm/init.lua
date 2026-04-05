local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local theme = require("my.parameters").theme

return {
	{
		"akinsho/toggleterm.nvim",
		opts = {
			direction = "float",
			on_open = function(term)
				require("plugins.toggleterm.utils").on_open(term)
			end,
			size = function(term)
				if term.direction == "horizontal" then
					return require("my.parameters").pane_width
				end
				return vim.o.columns * 0.4
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
				"<m-u>",
				function()
					require("plugins.toggleterm.utils").toggle_float()
				end,
				mode = { "n", "x", "i", "t" },
				desc = "Toggle Terminal",
			},
			{
				"oao",
				function()
					require("plugins.toggleterm.terms").term("agent"):toggle()
				end,
				desc = "Toggle Terminal agent",
			},
			{
				"oaf",
				function()
					require("plugins.toggleterm.terms").send_lines("agent", { require("plugins.toggleterm.agent").current_file_ref() })
				end,
				desc = "Send current file to agent",
			},
			{
				"oal",
				function()
					require("plugins.toggleterm.terms").send_lines("agent", { require("plugins.toggleterm.agent").current_line_ref() })
				end,
				desc = "Send current line to agent",
			},
			{
				"oac",
				function()
					require("plugins.toggleterm.terms").send_lines("agent", { require("plugins.toggleterm.agent").current_position_ref() })
				end,
				desc = "Send current position to agent",
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
				"oi",
				function()
					local term = require("plugins.toggleterm.terms").from_filetype()
					if term then
						term:toggle()
					end
				end,
				desc = "Toggle Terminal Filetype",
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
