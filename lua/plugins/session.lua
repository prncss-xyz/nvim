local not_vscode = require("my.conds").not_vscode

return {
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
