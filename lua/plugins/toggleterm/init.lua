local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local reverse = require("my.parameters").reverse
local theme = require("my.parameters").theme
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
				domain.move .. "a",
				function()
					require("plugins.toggleterm.terms").toggle({ key = "artifact" })
				end,
				desc = "Artifact Index",
			},
			{
				domain.pick .. theme.run,
				function()
					require("plugins.toggleterm.terms").toggle({
						prompt = "Select Terminal",
						dir = require("plugins.toggleterm.terms.get_query_fn").any,
					})
				end,
				desc = "Select Any Terminal",
			},
			{
				domain.pick .. reverse(theme.run),
				function()
					require("plugins.toggleterm.terms").focus({ prompt = "Select Terminal" })
				end,
				desc = "Select Terminal",
			},
			{
				"mb",
				function()
					require("plugins.toggleterm.terms").toggle_unseen_or_latest()
				end,
				desc = "Toggle Last Terminal",
				mode = { "n", "x", "i", "t" },
			},
			{
				ai_insert.toggle,
				function()
					require("plugins.toggleterm.terms").toggle()
				end,
				desc = "Toggle Last Terminal",
				mode = { "n", "x", "i", "t" },
			},
			{
				"ru",
				function()
					require("plugins.toggleterm.terms").toggle_panel({
						dir = require("plugins.toggleterm.terms.get_query_fn").any,
					})
				end,
				desc = "Toggle Tasks Panel",
				mode = { "n", "x" },
			},
			{
				"oi",
				function()
					require("plugins.toggleterm.repl").op:call({ domain = "outer" }, {
						i = function()
							require("plugins.toggleterm.terms").focus({ key = "repl" })
						end,
					})
				end,
				desc = "Toggle REPL",
				mode = { "n", "x" },
			},
			{
				"ou",
				function()
					require("plugins.toggleterm.terms").focus({ key = "test" })
				end,
				desc = "Toggle Terminal Test",
			},
			{
				"o" .. reverse("e"),
				function()
					require("plugins.toggleterm.terms").start({ key = "shell" })
				end,
				desc = "New Terminal Shell",
			},
			{
				"oe",
				function()
					require("plugins.toggleterm.terms").focus({ key = "shell" })
				end,
				desc = "Toggle Terminal Shell",
			},
			{
				"o" .. reverse("r"),
				function()
					require("plugins.toggleterm.terms").start({ key = "home shell" })
				end,
				desc = "New Terminal Home Shell",
			},
			{
				"or",
				function()
					require("plugins.toggleterm.terms").focus({ key = "home shell" })
				end,
				desc = "Toggle Terminal Home Shell",
			},
			{
				"oyw",
				function()
					require("plugins.toggleterm.terms").browse()
				end,
				desc = "Browse Terminal",
			},
			{
				"ow",
				function()
					require("plugins.toggleterm.terms").run()
				end,
				desc = "Select Command",
			},
			{
				"oz",
				function()
					require("plugins.toggleterm.harness").with_worktree()
				end,
				desc = "With Worktree",
			},
			{
				"o" .. reverse("z"),
				function()
					require("plugins.toggleterm.harness").pick_with_worktree()
				end,
				desc = "Pick With Worktree",
			},
			{
				"oo",
				function()
					require("plugins.toggleterm.terms").focus({ key = "diff" })
				end,
				desc = "Toggle Terminal Diff",
			},
			{
				"ma",
				function()
					require("plugins.toggleterm.terms").focus({ tag = "agent" })
				end,
				desc = "Focus Agent",
				mode = "n",
			},
			{
				"m" .. reverse("a"),
				function()
					require("plugins.toggleterm.terms").start({ tag = "agent" })
				end,
				desc = "New Agent",
				mode = "n",
			},
			{
				"ma",
				function()
					require("plugins.toggleterm.put.init").put_selection()
				end,
				desc = "Send Selection to Agent",
				mode = "x",
			},
			{
				"mc",
				function()
					require("plugins.toggleterm.put.init").put_file_pos()
				end,
				desc = "Put Current File Position",
				mode = "n",
			},
			{
				"md",
				function()
					require("plugins.toggleterm.put.init").put_file_line()
				end,
				desc = "Put Current File Line",
				mode = "n",
			},
			{
				"me",
				function()
					require("plugins.toggleterm.put.init").put_file_name()
				end,
				desc = "Put Current File Path",
				mode = "n",
			},
			{
				"mh",
				function()
					require("plugins.toggleterm.put.init").put_hunk()
				end,
				desc = "Put Current or Next Hunk",
				mode = "n",
			},
			{
				"mm",
				function()
					require("plugins.toggleterm.prompts").prompt()
				end,
				desc = "Put Prompt Result",
				mode = { "n", "x" },
			},
			{
				"mr",
				function()
					require("plugins.toggleterm.terms").restart({})
				end,
				desc = "Restart Last Terminal",
				mode = { "n", "x" },
			},
			{
				"my",
				function()
					require("plugins.toggleterm.terms").focus({ key = "ddgr" })
				end,
				desc = "ddgr",
				mode = "n",
			},
			{
				"mz",
				function()
					require("plugins.toggleterm.put.init").put_diagnostics("next")
				end,
				desc = "Put Diagnostic Prompt",
				mode = "n",
			},
			{
				"mpz",
				function()
					require("plugins.toggleterm.put.init").put_diagnostics("file")
				end,
				desc = "Put File Diagnostics Prompt",
			},
		},
		cond = not_vscode,
	},
}
