local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local reverse = require("my.parameters")
local theme = require("my.parameters").theme
local ai = domain.ai
local ai_insert = require("my.parameters").ai_insert

return {
	{
		"akinsho/toggleterm.nvim",
		opts = {
			direction = "float",
			persist_size = false,
			float_opts = {
				border = { "", "", "", "", "", "", "", "│" },
				width = function()
					return math.max(1, math.min(80, vim.o.columns - 4))
				end,
				height = function()
					local showtabline = vim.opt.showtabline:get()
					local has_tabline = showtabline == 2 or (showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
					local row_offset = has_tabline and 1 or 0

					local laststatus = vim.opt.laststatus:get()
					local has_statusline = laststatus == 2
						or laststatus == 3
						or (laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1)
					local status_offset = has_statusline and 1 or 0

					local cmdheight = vim.opt.cmdheight:get()
					return vim.o.lines - row_offset - status_offset - cmdheight
				end,
				row = function()
					local showtabline = vim.opt.showtabline:get()
					local has_tabline = showtabline == 2 or (showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
					return has_tabline and 1 or 0
				end,
				col = function()
					local w = math.max(1, math.min(80, vim.o.columns - 4))
					return vim.o.columns - w
				end,
				winblend = 0,
			},
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
					require("plugins.toggleterm.ops").repl_op:call({ domain = "outer" }, {
						i = function()
							require("plugins.toggleterm.terms").focus_term("repl")
						end,
					})
				end,
				desc = "Toggle REPL",
				mode = { "n", "x" },
			},
			{
				ai,
				function()
					require("plugins.toggleterm.ops").agent_op:call({ domain = "outer" }, {
						a = function()
							local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
							if not key then
								return
							end
							require("plugins.toggleterm.terms").focus_term(key)
						end,
						c = function()
							require("plugins.toggleterm.agents").send_current_position()
						end,
						e = function()
							require("plugins.toggleterm.agents").send_current_file()
						end,
						u = function()
							require("plugins.toggleterm.agents").prompt()
						end,
						x = function()
							require("plugins.toggleterm.agents").new()
						end,
						z = function()
							require("plugins.toggleterm.agents").diagnostic()
						end,
						Z = function()
							require("plugins.toggleterm.agents").file_diagnostics()
						end,
					})
				end,
				desc = "Toggle agent",
				mode = { "n", "x" },
			},
			{
				"ou",
				function()
					require("plugins.toggleterm.terms").focus_term("test")
				end,
				desc = "Toggle Terminal Test",
			},
			{
				"oe",
				function()
					require("plugins.toggleterm.terms").focus_term("shell")
				end,
				desc = "Toggle Terminal Shell",
			},
			{
				"or",
				function()
					require("plugins.toggleterm.terms").focus_term("home shell")
				end,
				desc = "Toggle Terminal Home Shell",
			},
			{
				"ow",
				function()
					require("plugins.toggleterm.terms").select_command()
				end,
				desc = "Toggle Terminal Dev",
			},
			{
				"opw",
				function()
					require("plugins.toggleterm.terms").select_command(true)
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
