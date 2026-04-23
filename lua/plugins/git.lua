local not_vscode = require("my.conds").not_vscode
local conflict = require("my.parameters").domain.conflict

return {
	{
		"lewis6991/gitsigns.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
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
		cond = not_vscode,
	},
	{
		"esmuellert/codediff.nvim",
		opts = {
			diff = {
				layout = "inline",
			},
		},
		cmd = "CodeDiff",
	},
	{
		"akinsho/git-conflict.nvim",
		version = "*",
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
				require("trouble").open({ mode = "quickfix" })
			end,
			highlights = {
				incoming = "DiffAdd",
				current = "DiffText",
			},
		},
		cond = not_vscode,
		cmd = "GitConflictListQf",
		keys = {
			{ conflict .. "l", "<cmd>GitConflictListQf<cr>", desc = "List Conflicts" },
		},
	},
}
