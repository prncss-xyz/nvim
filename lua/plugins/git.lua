local not_vscode = require("my.conds").not_vscode
local theme = require("my.parameters").theme
local git = require("my.parameters").domain.git

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
		-- cond = not_vscode,
	},
	{
		"TimUntersberger/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
		},
		opts = {
			disable_builtin_notifications = true,
			kind = "split",
			integrations = {
				diffview = true,
			},
		},
		keys = {
			{
				git .. theme.hunk,
				function()
					require("neogit").open()
				end,
				desc = "Neogit",
			},
			{
				git .. "A",
				function()
					require("neogit").open({ "cherry_pick" })
				end,
				desc = "Neogit Cherry Pick",
			},
			{
				git .. "B",
				function()
					require("neogit").open({ "bisect" })
				end,
				desc = "Neogit Bisect",
			},
			{
				git .. "b",
				function()
					require("neogit").open({ "branch" })
				end,
				desc = "Neogit Branch",
			},
			{
				git .. ",b",
				function()
					require("neogit").open({ "branch_config" })
				end,
				desc = "Neogit Branch Config",
			},
			{
				git .. "c",
				function()
					require("neogit").open({ "commit" })
				end,
				desc = "Neogit Commit",
			},
			{
				git .. "d",
				function()
					require("neogit").open({ "diff" })
				end,
				desc = "Neogit Diff",
			},
			{
				git .. "f",
				function()
					require("neogit").open({ "fetch" })
				end,
				desc = "Neogit Fetch",
			},
			{
				git .. "?",
				function()
					require("neogit").open({ "help" })
				end,
				desc = "Neogit Help",
			},
			{
				git .. "i",
				function()
					require("neogit").open({ "ignore" })
				end,
				desc = "Neogit Ignore",
			},
			{
				git .. "l",
				function()
					require("neogit").open({ "log" })
				end,
				desc = "Neogit Log",
			},
			{
				git .. "m",
				function()
					require("neogit").open({ "merge" })
				end,
				desc = "Neogit Merge",
			},
			{
				git .. "p",
				function()
					require("neogit").open({ "pull" })
				end,
				desc = "Neogit Pull",
			},
			{
				git .. "P",
				function()
					require("neogit").open({ "push" })
				end,
				desc = "Neogit Push",
			},
			{
				git .. "r",
				function()
					require("neogit").open({ "rebase" })
				end,
				desc = "Neogit Rebase",
			},
			{
				git .. "M",
				function()
					require("neogit").open({ "remote" })
				end,
				desc = "Neogit Remote",
			},
			{
				git .. ",M",
				function()
					require("neogit").open({ "remote_config" })
				end,
				desc = "Neogit Remote Config",
			},
			{
				git .. "X",
				function()
					require("neogit").open({ "reset" })
				end,
			},
			{
				git .. "v",
				function()
					require("neogit").open({ "revert" })
				end,
				desc = "Neogit Revert",
			},
			{
				git .. "Z",
				function()
					require("neogit").open({ "stash" })
				end,
				desc = "Neogit Stash",
			},
			{
				git .. "t",
				function()
					require("neogit").open({ "tag" })
				end,
				desc = "Neogit Tag",
			},
			{
				git .. "w",
				function()
					require("neogit").open({ "worktree" })
				end,
				desc = "Neogit Worktree",
			},
		},
		cmd = "Neogit",
		cond = not_vscode,
	},
	{
		"sindrets/diffview.nvim",
		cmd = {
			"DiffviewFileHistory",
			"DiffviewOpen",
			"DiffviewClose",
			"DiffviewFocusFiles",
			"DiffviewToggleFiles",
			"DiffviewRefresh",
		},
	},
}
