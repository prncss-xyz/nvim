local not_vscode = require("my.conds").not_vscode

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
		"TimUntersberger/neogit",
		opts = {
			disable_builtin_notifications = true,
			kind = "split",
			integrations = {
				diffview = true,
			},
		},
	},
	cmd = "Neogit",
}
