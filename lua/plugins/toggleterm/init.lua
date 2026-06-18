local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local reverse = require("my.parameters").reverse
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
		config = function(_, opts)
			require("toggleterm").setup(opts)
			-- toggleterm closes floating terminals on WinLeave by default.
			-- replace that autocmd with one that preserves floats when focus moves away.
			local group = "ToggleTermCommands"
			local pattern = { "term://*#toggleterm#*", "term://*::toggleterm::*" }
			vim.api.nvim_clear_autocmds({ event = "WinLeave", group = group })
			vim.api.nvim_create_autocmd("WinLeave", {
				pattern = pattern,
				group = group,
				callback = function()
					local _, term = require("toggleterm.terminal").identify()
					if not term then
						return
					end
					if require("toggleterm.config").persist_mode then
						term:persist_mode()
					end
					-- do NOT close floats on WinLeave
				end,
			})
		end,
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
				domain.pick .. reverse(theme.run),
				function()
					require("plugins.toggleterm.terms").select_any_term()
				end,
				desc = "Select Any Terminal",
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
			{
				"na",
				function()
					require("plugins.toggleterm.terms").with_tag("agent")
				end,
				desc = "Focus Agent",
				mode = "n",
			},
			{
				"na",
				function()
					require("plugins.toggleterm.last_win").put_selection_to_term("agent")
				end,
				desc = "Send Selection to Agent",
				mode = "x",
			},
			{
				"ne",
				function()
					require("plugins.toggleterm.last_win").put_last_file_name()
				end,
				desc = "Put Current File Path",
				mode = "n",
			},
			{
				"nd",
				function()
					require("plugins.toggleterm.last_win").put_last_file_line()
				end,
				desc = "Put Current File Line",
				mode = "n",
			},
			{
				"nc",
				function()
					require("plugins.toggleterm.last_win").put_last_file_pos()
				end,
				desc = "Put Current File Position",
				mode = "n",
			},
			{
				"nz",
				function()
					require("plugins.toggleterm.last_win").put_diagnostic_prompt()
				end,
				desc = "Put Diagnostic Prompt",
				mode = "n",
			},
			{
				"nz",
				function()
					require("plugins.toggleterm.last_win").put_file_diagnostics_prompt()
				end,
				desc = "Put File Diagnostics Prompt",
				mode = "n",
			},
		},
		cond = not_vscode,
	},
}
