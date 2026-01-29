local not_vscode = require("my.conds").not_vscode
local theme = require("my.parameters").theme
local git = require("my.parameters").domain.git
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
					require("my.ui_toggle").activate("neogit")
				end,
				desc = "Neogit",
			},
			{
				git .. "A",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "cherry_pick" })
					end)
				end,
				desc = "Neogit Cherry Pick",
			},
			{
				git .. "B",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "bisect" })
					end)
				end,
				desc = "Neogit Bisect",
			},
			{
				git .. ",b",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "branch_config" })
					end)
				end,
				desc = "Neogit Branch Config",
			},
			{
				git .. "c",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "commit" })
					end)
				end,
				desc = "Neogit Commit",
			},
			{
				git .. "d",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "diff" })
					end)
				end,
				desc = "Neogit Diff",
			},
			{
				git .. "f",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "fetch" })
					end)
				end,
				desc = "Neogit Fetch",
			},
			{
				git .. "?",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "help" })
					end)
				end,
				desc = "Neogit Help",
			},
			{
				git .. "i",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "ignore" })
					end)
				end,
				desc = "Neogit Ignore",
			},
			{
				git .. "l",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "log" })
					end)
				end,
				desc = "Neogit Log",
			},
			{
				git .. "m",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "merge" })
					end)
				end,
				desc = "Neogit Merge",
			},
			{
				git .. "p",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "pull" })
					end)
				end,
				desc = "Neogit Pull",
			},
			{
				git .. "P",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "push" })
					end)
				end,
				desc = "Neogit Push",
			},
			{
				git .. "M",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "remote" })
					end)
				end,
				desc = "Neogit Remote",
			},
			{
				git .. ",M",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "remote_config" })
					end)
				end,
				desc = "Neogit Remote Config",
			},
			{
				git .. "X",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "reset" })
					end)
				end,
			},
			{
				git .. "v",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "revert" })
					end)
				end,
				desc = "Neogit Revert",
			},
			{
				git .. "Z",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "stash" })
					end)
				end,
				desc = "Neogit Stash",
			},
			{
				git .. "t",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "tag" })
					end)
				end,
				desc = "Neogit Tag",
			},
			{
				git .. "w",
				function()
					require("my.ui_toggle").activate("neogit", function()
						require("neogit").open({ "worktree" })
					end)
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
		keys = {
			{ git .. "e", "<cmd>DiffviewFileHistory %<CR>", desc = "Diffview Current File History" },
			{ git .. "E", "<cmd>DiffviewOpen<CR>", desc = "Diffview Open" },
			{ git .. "q", "<cmd>DiffviewClose<CR>", desc = "Diffview Close" },
			{ git .. "F", "<cmd>DiffviewFocusFiles<CR>", desc = "Diffview Focus Files" },
			{ git .. "T", "<cmd>DiffviewToggleFiles<CR>", desc = "Diffview Toggle Files" },
			{ git .. "R", "<cmd>DiffviewRefresh<CR>", desc = "Diffview Refresh" },
		},
	},
	{
		"akinsho/git-conflict.nvim",
		version = "*",
		config = {
			default_mappings = {
				ours = conflict .. "o",
				theirs = conflict .. "t",
				none = conflict .. "x",
				both = conflict .. "b",
				next = conflict .. "n",
				prev = conflict .. "p",
			},
			default_commands = true,
			disable_diagnostics = false,
			list_opener = "copen",
			highlights = {
				incoming = "DiffAdd",
				current = "DiffText",
			},
		},
	},
}
