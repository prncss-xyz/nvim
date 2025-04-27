local domain = require("my.parameters").domain
local pane = domain.pane
local theme = require("my.parameters").theme
local reverse = require("my.parameters").reverse
local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

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
				pane .. "c",
				"<cmd>Trouble lsp_outgoing_calls toggle focus=false<cr>",
				desc = "Trouble LSP",
			},
			{
				pane .. reverse("c"),
				"<cmd>Trouble lsp_incoming_calls toggle focus=false<cr>",
				desc = "Trouble LSP",
			},
			{
				pane .. "l",
				"<cmd>Trouble lsp toggle focus=false<cr>",
				desc = "Trouble LSP",
			},
			{
				pane .. "q",
				"<cmd>Trouble qflist toggle<cr>",
				desc = "Trouble Quickfix List",
			},
			{
				pane .. theme.reference,
				"<cmd>Trouble lsp_references toggle<cr>",
				desc = "Trouble Diagnostics",
			},
			{
				pane .. theme.symbol,
				"<cmd>Trouble symbols toggle focus=false<cr>",
				desc = "Trouble Symbols",
			},
			{
				pane .. theme.diagnostic,
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
					title = "Overseer",
					ft = "OverseerList",
				},
				{
					title = "Aerial",
					ft = "aerial",
				},
				{
					title = "Trouble",
					ft = "trouble",
				},
				{
					title = "Neo-Tree",
					ft = "neo-tree",
				},
				{
					ft = "Outline",
					open = "SymbolsOutlineOpen",
				},
				-- any other neo-tree windows
				"neo-tree",
				{
					ft = "codecompanion",
					title = "Code Companion Chat",
				},
			},
			right = {
				{
					ft = "grug-far",
					title = "Grug Far",
				},
				{
					ft = "mchat",
					title = "Mchat",
				},
			},
		},
		keys = {
			{
				pane .. "q",
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
				"<c-o>",
				function()
					local id = require("window-picker").pick_window({
						hint = "floating-big-letter",
					})
					vim.api.nvim_set_current_win(id)
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
	{
		"4e554c4c/darkman.nvim",
		event = "VimEnter",
		build = "go build -o bin/darkman.nvim",
		enabled = false and personal,
		cond = not_vscode,
	},
}
