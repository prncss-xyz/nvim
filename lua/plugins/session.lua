local not_vscode = require("my.conds").not_vscode

return {
	{
		"notjedi/nvim-rooter.lua",
		commit = "7689d05",
		opts = {
			rooter_patterns = { ".git", ".hg", ".svn" },
			exclude_filetypes = { "neo-tree", "snacks_picker_input" },
		},
		name = "nvim-rooter",
		event = "VimEnter",
		cmd = { "Rooter", "RooterToggle" },
		cond = not_vscode,
	},
	{
		"ethanholz/nvim-lastplace",
		-- repo is archived
		commit = "0bb6103",
		event = "BufReadPre",
		opts = {
			lastplace_ignore_buftype = { "quickfix", "nofile", "help" },
			lastplace_ignore_filetype = {
				"gitcommit",
				"gitrebase",
				"svn",
				"hgcommit",
			},
		},
		cond = not_vscode,
	},
}
