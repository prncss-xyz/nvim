local domain = require("my.parameters").domain
local win = domain.win
local theme = require("my.parameters").theme
local reverse = require("my.parameters").reverse
local not_vscode = require("my.conds").not_vscode

return {
	{
		"folke/trouble.nvim",
		opts = {
			position = "left",
			use_diagnostic_signs = true,
		},
		cmd = { "Trouble" },
		keys = {
			{
				win .. "c",
				"<cmd>Trouble lsp_outgoing_calls toggle focus=false<cr>",
				desc = "Trouble LSP",
			},
			{
				win .. reverse("c"),
				"<cmd>Trouble lsp_incoming_calls toggle focus=false<cr>",
				desc = "Trouble LSP",
			},
			{
				win .. "l",
				"<cmd>Trouble lsp toggle focus=false<cr>",
				desc = "Trouble LSP",
			},
			{
				win .. "q",
				"<cmd>Trouble qflist toggle<cr>",
				desc = "Trouble Quickfix List",
			},
			{
				win .. theme.reference,
				"<cmd>Trouble lsp_references toggle<cr>",
				desc = "Trouble Diagnostics",
			},
			{
				win .. reverse(theme.symbol),
				"<cmd>Trouble symbols toggle focus=false<cr>",
				desc = "Trouble Symbols",
			},
			{
				win .. theme.diagnostic,
				"<cmd>Trouble diagnostics toggle<cr>",
				desc = "Trouble Diagnostics",
			},
			{
				domain.move .. reverse("t"),
				function()
					require("flies.actions.move_again").recompose2(function()
						require("trouble").previous({
							skip_groups = true,
							jump = true,
						})
					end, function()
						require("trouble").next({
							skip_groups = true,
							jump = true,
						})
					end, false)
				end,
				desc = "Trouble prev",
			},
			{
				domain.move .. "t",
				function()
					require("flies.actions.move_again").recompose2(function()
						require("trouble").previous({
							skip_groups = true,
							jump = true,
						})
					end, function()
						require("trouble").next({
							skip_groups = true,
							jump = true,
						})
					end, true)
				end,
				desc = "Trouble next",
			},
		},
		cond = not_vscode,
	},
	{
		"folke/noice.nvim",
		event = "VimEnter",
		cmd = "Noice",
		opts = {
			commands = {
				history = {
					view = "popup",
				},
			},
			lsp = {
				progress = {
					-- ltex_ls gets really annoying otherwise
					throttle = 1000,
				},
				-- override markdown rendering so that **cmp** and other plugins use **Treesitter**
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
			},
			-- you can enable a preset for easier configuration
			presets = {
				bottom_search = false, -- use a classic bottom cmdline for search
				command_palette = false, -- position the cmdline and popupmenu together
				long_message_to_split = true, -- long messages will be sent to a split
				inc_rename = false, -- enables an input dialog for inc-rename.nvim
				lsp_doc_border = false, -- add a border to hover docs and signature help
			},
			messages = {
				view_search = false,
			},
		},
		cond = not_vscode,
	},
	{
		"folke/edgy.nvim",
		event = "VeryLazy",
		init = function()
			vim.opt.laststatus = 3
			vim.opt.splitkeep = "screen"
		end,
		opts = {
			options = {
				left = { size = 40 },
				right = { size = 60 },
			},
			left = {
				{
					ft = "OverseerList",
				},
				{
					ft = "aerial",
				},
				{
					ft = "trouble",
				},
				{
					ft = "neo-tree",
				},
				{
					ft = "codecompanion",
				},
				{
					ft = "copilot-chat",
					size = { width = 50 },
				},
				{
					ft = "grug-far",
				},
			},
		},
		keys = {
			{
				win .. "q",
				function()
					require("edgy").toggle()
				end,
				desc = "Pick Window",
			},
		},
		cond = not_vscode,
	},
	{
		"kevinhwang91/nvim-hlslens",
		name = "hlslens",
		opts = {
			calm_down = true,
		},
		event = "VeryLazy",
		cond = not_vscode,
	},
	{
		"s1n7ax/nvim-window-picker",
		commit = "6382540",
		opts = {
			selection_chars = require("my.parameters").selection_chars:upper(),
			hint = "floating-big-letter",
			show_prompt = false,
			filter_rules = {
				include_current_win = false,
				bo = {
					filetype = {},
					buftype = {},
				},
			},
		},
		keys = {
			{
				"<c-i>",
				function()
					require("my.windows").list()
				end,
				mode = { "n", "x", "i" },
				desc = "List Windows",
			},
			{
				"<c-o>",
				function()
					local id = require("window-picker").pick_window()
					if id then
						vim.api.nvim_set_current_win(id)
					end
				end,
				mode = { "n", "x", "i" },
				desc = "Pick Window",
			},
		},
		cond = not_vscode,
	},
	{
		"RRethy/vim-illuminate",
		opts = {
			under_cursor = false,
			filetypes_denylist = { "NeogitStatus" },
		},
		config = function(_, opts)
			require("illuminate").configure(opts)
		end,
		event = "VeryLazy",
		-- enabled on vscode because we use it for movements
	},
}
