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
					close_on_open_in_prev_tab = true,
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
		keys = {
			{
				git .. "d",
				function()
					vim.cmd("CodeDiff")
				end,
				desc = "CodeDiff changes",
			},
			{
				git .. "m",
				function()
					local branch
					for _, candidate in ipairs({ "main", "master" }) do
						vim.fn.system({ "git", "rev-parse", "--verify", candidate })
						if vim.v.shell_error == 0 then
							branch = candidate
							break
						end
					end
					assert(branch, "Could not find a main or master branch")
					vim.cmd("CodeDiff " .. branch)
				end,
				desc = "Git CodeDiff default branch",
			},
			{
				git .. "l",
				"<cmd>CodeDiff HEAD~1 HEAD<cr>",
				desc = "CodeDiff latest commit against its parent",
			},
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
		enable = false,
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
			{ conflict .. "l", "<cmd>GitConflictListQf<cr>", desc = "Git List Conflicts" },
		},
	},
}
