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
		cond = require("my.conds").not_vscode,
	},
}
