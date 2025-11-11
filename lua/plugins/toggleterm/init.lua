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
				"oe",
				function()
					require("plugins.toggleterm.terms").terms.term_e:toggle()
				end,
				desc = "Toggle Terminal e",
			},
			{
				"or",
				function()
					require("plugins.toggleterm.terms").terms.term_r:toggle()
				end,
				desc = "Toggle Terminal r",
			},
			{
				"oi",
				function()
					require("plugins.toggleterm.terms").from_filetype():toggle()
				end,
				desc = "Toggle Terminal Filetype",
			},
			{
				"ols",
				function()
					require("plugins.toggleterm.terms").terms.dev:spawn({
						close_on_exit = false,
					})
				end,
				desc = "Spawn Terminal Dev",
			},
			{
				"ow",
				function()
					require("plugins.toggleterm.terms").terms.dev:toggle()
				end,
				desc = "Toggle Terminal Dev",
			},
			{
				"oo",
				function()
					require("plugins.toggleterm.terms").terms.term_o:toggle()
				end,
				desc = "Toggle Terminal Current file",
			},
			{
				"occ",
				function()
					require("plugins.toggleterm.terms").terms.diff:toggle()
				end,
				desc = "Toggle Terminal Diff",
			},
		},
		cond = not_vscode,
	},
}
