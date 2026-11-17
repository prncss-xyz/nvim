local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local file = domain.file
local reverse = require("my.parameters").reverse
local theme = require("my.parameters").theme
local ai_insert = require("my.parameters").ai_insert
local git = require("my.parameters").domain.git

return {
	{
		"prncss-xyz/neoplane.nvim",
		dev = true,
		lazy = false,
		dependencies = {
			"akinsho/toggleterm.nvim",
			unpack(vim.uv.os_gethostname() == "crotte" and { "https://github.com/gvvaughan/lyaml" } or {}),
		},
		init = function()
			vim.api.nvim_create_autocmd("User", {
				pattern = "VeryLazy",
				once = true,
				callback = function()
					require("neoplane.terms.artifacts.auto").start()
				end,
			})
			local group = vim.api.nvim_create_augroup("Neoterm", { clear = true })
			vim.api.nvim_create_autocmd({ "BufEnter" }, {
				group = group,
				nested = true,
				callback = function()
					require("neoplane.rooter").on_buf_enter()
				end,
			})
			vim.api.nvim_create_autocmd("WinEnter", {
				group = group,
				callback = function()
					require("neoplane.helpers.win_history").on_win_enter()
				end,
			})
		end,
		opts = function()
			return require("plugins.neoplane.config")
		end,
		keys = {
			{
				file .. "o",
				function()
					require("neoplane.helpers.edit_file_under_cursor")()
				end,
				desc = "Edit File Under Cursor",
			},
			{
				file .. "g",
				function()
					require("neoplane.git").clone_github()
				end,
				desc = "Clone or Create Github Repo",
			},
			{
				git .. reverse("w"),
				function()
					require("neoplane.git").remove_current_worktree()
				end,
				desc = "Delete Worktree",
			},
			{
				git .. "w",
				function()
					require("neoplane.git").create_worktree_from_input(function(default_file)
						require("my.create").create(default_file)
					end)
				end,
				desc = "Create Worktree",
			},
			{
				git .. "m",
				function()
					require("neoplane.git").merge_to_default()
				end,
				desc = "Merge to default",
			},
			{
				"<c-j>",
				function()
					require("neoplane.helpers.win_history").focus_last_win()
				end,
				desc = "Window Toggle File",
				mode = { "n", "x", "i", "t" },
			},
			{
				"bf",
				function()
					local cfile = vim.fn.expand("<cfile>")
					if cfile == "" then
						vim.notify("No file under cursor", vim.log.levels.WARN)
						return
					end
					local target_win = require("neoplane.helpers.win_history").get_last_file_win()
					if target_win then
						vim.api.nvim_set_current_win(target_win)
					end
					require("neoplane.config").create(cfile)
				end,
				desc = "open file in last visited file window",
			},
			{
				"ocw",
				function()
					require("neoplane.terms").restart({
						key = "word count",
						cmd = string.format("wc %q", vim.fn.expand("%")),
						on_exit = "keep",
					})
				end,
				desc = "Word Count",
				mode = { "n", "x" },
			},
			{
				"hf",
				function()
					require("neoplane.helpers.toggle_index_file")()
				end,
				desc = "Toggle Index File",
			},
			{
				domain.move .. "a",
				function()
					require("neoplane.terms").toggle({ key = "artifact" })
				end,
				desc = "Artifact Index",
			},
			{
				domain.pick .. reverse(theme.run),
				function()
					require("neoplane.terms").focus({ prompt = "Select Terminal" })
				end,
				desc = "Select Terminal",
			},
			{
				domain.pick .. theme.run,
				function()
					require("neoplane.terms").toggle({
						prompt = "Select Terminal",
						cwd = require("neoplane.terms.get_query_fn").any,
					})
				end,
				desc = "Select Any Terminal",
			},
			{
				"mb",
				function()
					require("neoplane.terms").toggle_unseen_or_latest({
						cwd = require("neoplane.terms.get_query_fn").any,
					})
				end,
				desc = "Toggle Last Terminal",
			},
			{
				ai_insert.toggle,
				function()
					require("neoplane.terms").toggle_or_default()
				end,
				desc = "Toggle Last Terminal",
				mode = { "n", "x", "i", "t" },
			},
			{
				"r" .. reverse("u"),
				function()
					require("my.ui_toggle").activate("toggleterm_tasks", function()
						require("neoplane.task_panel").toggle()
					end)
				end,
				desc = "Toggle Tasks Panel",
			},
			{
				"r.",
				function()
					require("my.ui_toggle").activate("toggleterm_auto", function()
						require("neoplane.auto_panel").toggle()
					end)
				end,
				desc = "Toggle Auto Steps Panel",
			},
			{
				"ru",
				function()
					require("my.ui_toggle").activate("toggleterm", function()
						require("neoplane.terms").toggle_panel({
							cwd = require("neoplane.terms.get_query_fn").any,
						})
					end)
				end,
				desc = "Toggle Terminal Panel",
				mode = { "n", "x" },
			},
			{
				"ou",
				function()
					require("neoplane.terms").focus({ key = "test" })
				end,
				desc = "Toggle Terminal Test",
			},
			{
				"o" .. reverse("e"),
				function()
					require("neoplane.terms").start({ key = "shell" })
				end,
				desc = "New Terminal Shell",
			},
			{
				"oe",
				function()
					require("neoplane.terms").focus({ key = "shell" })
				end,
				desc = "Toggle Terminal Shell",
			},
			{
				"o" .. reverse("r"),
				function()
					require("neoplane.terms").start({ key = "home shell" })
				end,
				desc = "New Terminal Home Shell",
			},
			{
				"or",
				function()
					require("neoplane.terms").focus({ key = "home shell" })
				end,
				desc = "Toggle Terminal Home Shell",
			},
			{
				"oyw",
				function()
					require("neoplane.terms").browse()
				end,
				desc = "Browse Terminal",
			},
			{
				"o" .. reverse("w"),
				function()
					require("neoplane.terms").run_or_raise(false)
				end,
				desc = "Run Command",
			},
			{
				"ow",
				function()
					require("neoplane.terms").run_or_raise(true)
				end,
				desc = "Run or Raise Command",
			},
			{
				"o" .. reverse("z"),
				function()
					require("neoplane.terms.artifacts.commands").select_for_current_file(true)
				end,
				desc = "Pick With Worktree",
			},
			{
				"oz",
				function()
					require("neoplane.terms.artifacts.commands").select_for_current_file()
				end,
				desc = "Run Buffer Step",
			},
			{
				"oo",
				function()
					require("neoplane.terms").focus({ key = "diff" })
				end,
				desc = "Toggle Terminal Diff",
			},
			{
				"m" .. reverse("a"),
				function()
					require("neoplane.terms").start({ tag = "agent" })
				end,
				desc = "New Agent",
			},
			{
				"ma",
				function()
					require("neoplane.terms").focus({ tag = "agent" })
				end,
				desc = "Focus Agent",
			},
			{
				"m" .. reverse("v"),
				function()
					require("neoplane.terms").put(
						{ tag = "agent" },
						"{selection_span}\n{selection_contents}",
						{ new = true }
					)
				end,
				desc = "Send Selection to New Agent",
				mode = { "n", "x" },
			},
			{
				"mv",
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{selection_span}\n{selection_contents}")
				end,
				desc = "Send Selection to Agent",
				mode = { "n", "x" },
			},
			{
				"m" .. reverse("a"),
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{selection_contents}", { new = true })
				end,
				desc = "Send Selection to New Agent",
				mode = "x",
			},
			{
				"ma",
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{selection_contents}")
				end,
				desc = "Send Selection to Agent",
				mode = "x",
			},
			{
				"m" .. reverse("c"),
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{position}", { new = true })
				end,
				desc = "Put Current File Position in New Agent",
			},
			{
				"mc",
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{position}")
				end,
				desc = "Put Current File Position",
			},
			{
				"m" .. reverse("s"),
				function()
					require("neoplane.helpers.frontmatter").add_dependency()
				end,
				desc = "Add Dependency",
				ft = "markdown",
			},
			{
				"ms",
				function()
					require("neoplane.helpers.frontmatter").update_status()
				end,
				desc = "Update Status",
				mode = "n",
				ft = "markdown",
			},
			{
				"m" .. reverse("d"),
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{line}", { new = true })
				end,
				desc = "Put Current File Line in New Agent",
			},
			{
				"md",
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{line}")
				end,
				desc = "Put Current File Line",
			},
			{
				"m" .. reverse("e"),
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{path}", { new = true })
				end,
				desc = "Put Current File Path in New Agent",
			},
			{
				"me",
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{path}")
				end,
				desc = "Put Current File Path",
			},
			{
				"m" .. reverse("h"),
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{hunk}", { new = true })
				end,
				desc = "Put Current or Next Hunk in New Agent",
			},
			{
				"mh",
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{hunk}")
				end,
				desc = "Put Current or Next Hunk",
			},
			{
				"mm",
				function()
					require("neoplane.prompts").prompt()
				end,
				desc = "Put Prompt Result",
				mode = { "n", "x" },
			},

			{
				"m" .. reverse("n"),
				function()
					require("neoplane.harness").focus_last_created_artifact()
				end,
				desc = "Focus Last Created Task",
				mode = { "n", "x" },
			},
			{
				"mn",
				function()
					require("neoplane.prompts").run(require("neoplane.helpers.prompt").create_task(true))
				end,
				desc = "New Task",
				mode = { "n", "x" },
			},
			{
				"mr",
				function()
					require("neoplane.terms").restart({})
				end,
				desc = "Restart Last Terminal",
				mode = { "n", "x" },
			},
			{
				"my",
				function()
					require("neoplane.terms").focus({ key = "ddgr" })
				end,
				desc = "ddgr",
			},
			{
				"m" .. reverse("z"),
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{next_diagnostic}", { new = true })
				end,
				desc = "Put Diagnostic Prompt in New Agent",
			},
			{
				"mz",
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{next_diagnostic}")
				end,
				desc = "Put Diagnostic Prompt",
			},
			{
				"m" .. reverse("f"),
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{file_diagnostic}", { new = true })
				end,
				desc = "Put File Diagnostics Prompt in New Agent",
			},
			{
				"mf",
				function()
					require("neoplane.terms").put({ tag = "agent" }, "{file_diagnostic}")
				end,
				desc = "Put File Diagnostics Prompt",
			},
			{
				"m" .. reverse("."),
				function()
					require("neoplane.terms.artifacts.auto").auto_trigger_next()
				end,
				desc = "Toggle auto trigger next",
			},
			{
				"m.",
				function()
					require("neoplane.terms.artifacts.auto").trigger_next()
				end,
				desc = "Trigger next",
			},
		},
		cond = not_vscode,
	},
}
