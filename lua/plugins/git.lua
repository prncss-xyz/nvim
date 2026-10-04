local not_vscode = require("my.conds").not_vscode
local conflict = require("my.parameters").domain.conflict
local git = require("my.parameters").domain.git
local win = require("my.parameters").domain.win
local theme = require("my.parameters").theme

return {
	{
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			on_attach = require("my.git_base").on_attach,
			watch_gitdir = {
				interval = 100,
			},
			sign_priority = 5,
			status_formatter = nil, -- Use default
			numhl = false,
			current_line_blame = true,
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol",
				delay = 1000,
				ignore_whitespace = false,
			},
			word_diff = false,
		},
		cmd = "Gitsigns",
		keys = {
			{ git .. "s", "<cmd>Gitsigns<cr>", desc = "Gitsigns" },
			{ git .. "h", "<cmd>Gitsigns preview_hunk<cr>", desc = "Gitsigns Preview Hunk" },
			{ git .. "x", "<cmd>Gitsigns reset_hunk<cr>", desc = "Gitsigns Reset Hunk" },
		},
		cond = not_vscode,
	},
	{
		"akinsho/git-conflict.nvim",
		version = "*",
		lazy = false,
		opts = {
			default_mappings = {
				ours = conflict .. "o",
				theirs = conflict .. "t",
				none = conflict .. "x",
				both = conflict .. "b",
				next = conflict .. "j",
				prev = conflict .. "k",
			},
			default_commands = true,
			disable_diagnostics = false,
			list_opener = function()
				require("my.ui_toggle").activate("trouble", function()
					require("trouble").open({ mode = "quickfix" })
				end)
			end,
			highlights = {
				incoming = "DiffAdd",
				current = "DiffText",
			},
		},
		cond = not_vscode,
		cmd = "GitConflictListQf",
		keys = {
			{
				win .. theme.hunk .. "k",
				"<cmd>GitConflictListQf<cr>",
				desc = "Git Conflicts Quickfix",
			},
		},
	},
}
