local not_vscode = require("my.conds").not_vscode
local conflict = require("my.parameters").domain.conflict
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
		keys = {
			{ git .. "s", "<cmd>Gitsigns<cr>", desc = "Gitsigns" },
			{ git .. "h", "<cmd>Gitsigns preview_hunk<cr>", desc = "Gitsigns Preview Hunk" },
			{ git .. "x", "<cmd>Gitsigns reset_hunk<cr>", desc = "Gitsigns Reset Hunk" },
		},
		cond = not_vscode,
	},
	{
		"esmuellert/codediff.nvim",
		opts = {
			explorer = {
				view_mode = "tree",
			},
			diff = {
				layout = "inline",
			},
			keymaps = {
				view = {
					next_hunk = ",n",
					prev_hunk = ",p",
					next_file = ",N",
					prev_file = ",P",
				},
			},
		},
		cmd = "CodeDiff",
		config = function(_, opts)
			require("codediff").setup(opts)
			-- Wrap the CodeDiff command to track the last invocation args
			local original_cmd = vim.api.nvim_get_commands({})["CodeDiff"]
			if original_cmd then
				vim.api.nvim_create_user_command("CodeDiffLast", function(cmd_opts)
					local args_str = cmd_opts.args or ""
					-- Don't track empty toggle invocations from within a diff tab
					if args_str ~= "" then
						_G._codediff_last_args = args_str
					end
					require("codediff.commands").vscode_diff(cmd_opts)
				end, {
					nargs = "*",
					bang = true,
					range = true,
					complete = original_cmd.complete,
				})
			end
		end,
		init = function()
			vim.keymap.set("n", git .. "l", function()
				if _G._codediff_last_args then
					vim.cmd("CodeDiff " .. _G._codediff_last_args)
				else
					vim.notify("No previous CodeDiff invocation", vim.log.levels.WARN)
				end
			end, { desc = "Git CodeDiff last" })
		end,
		keys = {
			{ git .. "d", "<cmd>CodeDiff<cr>", desc = "Git CodeDiff" },
			{
				git .. "m",
				function()
					local branch = vim.fn
						.system("git rev-parse --abbrev-ref origin/HEAD 2>/dev/null")
						:gsub("origin/", "")
						:gsub("\n", "")
					if vim.v.shell_error ~= 0 or branch == "" then
						branch = vim.fn
							.system("git branch --list main master --format='%(refname:short)' 2>/dev/null")
							:match("[^\n]+") or "main"
					end
					vim.cmd("CodeDiff " .. branch)
				end,
				desc = "Git CodeDiff default branch",
			},
			{ git .. "l", "<cmd>CodeDiffLast<cr>", desc = "Git CodeDiffLast" },
		},
		cond = not_vscode,
	},
	{
		"sindrets/diffview.nvim",
		-- maintained fork: dlyongemallo/diffview-plus.nvim
		opts = {},
		cmd = {
			"DiffviewOpen",
			"DiffviewClose",
			"DiffviewToggleFiles",
			"DiffviewFocusFiles",
			"DiffviewRefresh",
			"DiffviewFileHistory",
		},
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
		enable = false,
		cmd = "GitConflictListQf",
		keys = {
			{ conflict .. "l", "<cmd>GitConflictListQf<cr>", desc = "Git List Conflicts" },
		},
	},
}
