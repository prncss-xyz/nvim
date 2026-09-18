local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain
local reverse = require("my.parameters").reverse
local theme = require("my.parameters").theme
local ai_insert = require("my.parameters").ai_insert

return {
	{
		"akinsho/toggleterm.nvim",
		dependencies = vim.uv.os_gethostname() == "crotte" and { "https://github.com/gvvaughan/lyaml" } or {},
		opts = {
			direction = "float",
			persist_size = false,
			float_opts = {
				border = { "", "", "", "", "", "", "", "│" },
				width = function()
					return math.max(1, math.min(80, vim.o.columns - 4))
				end,
				height = function()
					local showtabline = vim.opt.showtabline:get()
					local has_tabline = showtabline == 2 or (showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
					local row_offset = has_tabline and 1 or 0

					local laststatus = vim.opt.laststatus:get()
					local has_statusline = laststatus == 2
						or laststatus == 3
						or (laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1)
					local status_offset = has_statusline and 1 or 0

					local cmdheight = vim.opt.cmdheight:get()
					return vim.o.lines - row_offset - status_offset - cmdheight
				end,
				row = function()
					local showtabline = vim.opt.showtabline:get()
					local has_tabline = showtabline == 2 or (showtabline == 1 and #vim.api.nvim_list_tabpages() > 1)
					return has_tabline and 1 or 0
				end,
				col = function()
					local w = math.max(1, math.min(80, vim.o.columns - 4))
					return vim.o.columns - w
				end,
				winblend = 0,
			},
		},
		config = function(_, opts)
			require("toggleterm").setup(opts)
			-- toggleterm closes floating terminals on WinLeave by default.
			-- replace that autocmd with one that preserves floats when focus moves away.
			local group = "ToggleTermCommands"
			local pattern = { "term://*#toggleterm#*", "term://*::toggleterm::*" }
			vim.api.nvim_clear_autocmds({ event = "WinLeave", group = group })
			vim.api.nvim_create_autocmd("WinLeave", {
				pattern = pattern,
				group = group,
				callback = function()
					local _, term = require("toggleterm.terminal").identify()
					if not term then
						return
					end
					if require("toggleterm.config").persist_mode then
						term:persist_mode()
					end
					-- do NOT close floats on WinLeave
				end,
			})
		end,
		cmd = {
			"ToggleTerm",
			"ToggleTermToggleAll",
			"TermExec",
			"TermSelect",
			"ToggleTermSetName",
		},
		keys = {
			{
				domain.move .. "a",
				function()
					require("plugins.toggleterm.terms").toggle({ key = "artifact" })
				end,
				desc = "Artifact Index",
			},
			{
				domain.pick .. theme.run,
				function()
					require("plugins.toggleterm.terms").toggle({
						prompt = "Select Terminal",
						cwd = require("plugins.toggleterm.terms.get_query_fn").any,
					})
				end,
				desc = "Select Any Terminal",
			},
			{
				domain.pick .. reverse(theme.run),
				function()
					require("plugins.toggleterm.terms").focus({ prompt = "Select Terminal" })
				end,
				desc = "Select Terminal",
			},
			{
				"mb",
				function()
					require("plugins.toggleterm.terms").toggle_unseen_or_latest()
				end,
				desc = "Toggle Last Terminal",
			},
			{
				ai_insert.toggle,
				function()
					require("plugins.toggleterm.terms").toggle()
				end,
				desc = "Toggle Last Terminal",
				mode = { "n", "x", "i", "t" },
			},
			{
				"ru",
				function()
					require("my.ui_toggle").activate("toggleterm", function()
						require("plugins.toggleterm.terms").toggle_panel({
							cwd = require("plugins.toggleterm.terms.get_query_fn").any,
						})
					end)
				end,
				desc = "Toggle Terminal Panel",
				mode = { "n", "x" },
			},
			{
				"r" .. reverse("u"),
				function()
					require("my.ui_toggle").activate("toggleterm_tasks", function()
						require("plugins.toggleterm.task_panel").toggle()
					end)
				end,
				desc = "Toggle Tasks Panel",
			},
			{
				"oi",
				function()
					require("plugins.toggleterm.repl").op:call({ domain = "outer" }, {
						i = function()
							require("plugins.toggleterm.terms").focus({ key = "repl" })
						end,
					})
				end,
				desc = "Toggle REPL",
				mode = { "n", "x" },
			},
			{
				"ou",
				function()
					require("plugins.toggleterm.terms").focus({ key = "test" })
				end,
				desc = "Toggle Terminal Test",
			},
			{
				"o" .. reverse("e"),
				function()
					require("plugins.toggleterm.terms").start({ key = "shell" })
				end,
				desc = "New Terminal Shell",
			},
			{
				"oe",
				function()
					require("plugins.toggleterm.terms").focus({ key = "shell" })
				end,
				desc = "Toggle Terminal Shell",
			},
			{
				"o" .. reverse("r"),
				function()
					require("plugins.toggleterm.terms").start({ key = "home shell" })
				end,
				desc = "New Terminal Home Shell",
			},
			{
				"or",
				function()
					require("plugins.toggleterm.terms").focus({ key = "home shell" })
				end,
				desc = "Toggle Terminal Home Shell",
			},
			{
				"oyw",
				function()
					require("plugins.toggleterm.terms").browse()
				end,
				desc = "Browse Terminal",
			},
			{
				"ow",
				function()
					require("plugins.toggleterm.terms").run_or_raise()
				end,
				desc = "Select Command",
			},
			{
				"oz",
				function()
					local definitions = require("plugins.toggleterm.artifact_commands").for_file({
						cwd = require("plugins.toggleterm.terms.artifact_cwd").context_dir() or vim.fn.getcwd(),
						file = vim.api.nvim_buf_get_name(0),
						tasks = require("plugins.toggleterm.config").tasks,
					})
					vim.ui.select(definitions, {
						prompt = "Select Buffer Task: ",
						format_item = function(definition)
							return definition.name
						end,
					}, function(definition)
						if definition == nil then
							return
						end
						local task = definition.builder({})
						task.key = definition.name
						task.display_name = definition.name
						task.tag = definition.name
						task.exit_policy = task.exit_policy or "close"
						require("plugins.toggleterm.terms").start(task)
					end)
				end,
				desc = "Run Buffer Task",
			},
			{
				"o" .. reverse("z"),
				function()
					require("plugins.toggleterm.harness").pick_with_worktree()
				end,
				desc = "Pick With Worktree",
			},
			{
				"oo",
				function()
					require("plugins.toggleterm.terms").focus({ key = "diff" })
				end,
				desc = "Toggle Terminal Diff",
			},
			{
				"m" .. reverse("a"),
				function()
					require("plugins.toggleterm.terms").start({ tag = "agent" })
				end,
				desc = "New Agent",
				mode = "n",
			},
			{
				"ma",
				function()
					require("plugins.toggleterm.terms").focus({ tag = "agent" })
				end,
				desc = "Focus Agent",
				mode = "n",
			},
			{
				"mv",
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{selection}")
				end,
				desc = "Send Selection to Agent",
			},
			{
				"m" .. reverse("v"),
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{selection}", { new = true })
				end,
				desc = "Send Selection to New Agent",
			},
			{
				"ma",
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{selection}")
				end,
				desc = "Send Selection to Agent",
				mode = "x",
			},
			{
				"m" .. reverse("a"),
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{selection}", { new = true })
				end,
				desc = "Send Selection to New Agent",
				mode = "x",
			},
			{
				"mc",
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{position}")
				end,
				desc = "Put Current File Position",
				mode = "n",
			},
			{
				"m" .. reverse("c"),
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{position}", { new = true })
				end,
				desc = "Put Current File Position in New Agent",
				mode = "n",
			},
			{
				"mps",
				function()
					require("plugins.toggleterm.helpers.frontmatter").add_dependency()
				end,
				desc = "Add Dependency",
				ft = "markdown",
			},
			{
				"ms",
				function()
					require("plugins.toggleterm.helpers.frontmatter").update_status()
				end,
				desc = "Update Status",
				mode = "n",
				ft = "markdown",
			},
			{
				"md",
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{line}")
				end,
				desc = "Put Current File Line",
				mode = "n",
			},
			{
				"m" .. reverse("d"),
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{line}", { new = true })
				end,
				desc = "Put Current File Line in New Agent",
				mode = "n",
			},
			{
				"me",
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{path}")
				end,
				desc = "Put Current File Path",
				mode = "n",
			},
			{
				"m" .. reverse("e"),
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{path}", { new = true })
				end,
				desc = "Put Current File Path in New Agent",
				mode = "n",
			},
			{
				"mh",
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{hunk}")
				end,
				desc = "Put Current or Next Hunk",
				mode = "n",
			},
			{
				"m" .. reverse("h"),
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{hunk}", { new = true })
				end,
				desc = "Put Current or Next Hunk in New Agent",
				mode = "n",
			},
			{
				"mm",
				function()
					require("plugins.toggleterm.prompts").prompt()
				end,
				desc = "Put Prompt Result",
				mode = { "n", "x" },
			},
			{
				"m" .. reverse("n"),
				function()
					require("plugins.toggleterm.harness").focus_last_created_artifact()
				end,
				desc = "Focus Last Created Task",
				mode = { "n", "x" },
			},
			{
				"mn",
				function()
					-- TODO: make this more convenient
					require("plugins.toggleterm.prompts").run(
						require("plugins.toggleterm.helpers.prompt").create_task(true)
					)
				end,
				desc = "New Task",
				mode = { "n", "x" },
			},
			{
				"m" .. reverse("m"),
				function()
					require("plugins.toggleterm.prompts").prompt(true)
				end,
				desc = "Put Prompt Result in New Agent",
				mode = { "n", "x" },
			},
			{
				"mr",
				function()
					require("plugins.toggleterm.terms").restart({})
				end,
				desc = "Restart Last Terminal",
				mode = { "n", "x" },
			},
			{
				"my",
				function()
					require("plugins.toggleterm.terms").focus({ key = "ddgr" })
				end,
				desc = "ddgr",
				mode = "n",
			},
			{
				"mz",
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{next_diagnostic}")
				end,
				desc = "Put Diagnostic Prompt",
				mode = "n",
			},
			{
				"m" .. reverse("z"),
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{next_diagnostic}", { new = true })
				end,
				desc = "Put Diagnostic Prompt in New Agent",
				mode = "n",
			},
			{
				"mf",
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{file_diagnostic}")
				end,
				desc = "Put File Diagnostics Prompt",
			},
			{
				"m" .. reverse("f"),
				function()
					require("plugins.toggleterm.terms").put({ tag = "agent" }, "{file_diagnostic}", { new = true })
				end,
				desc = "Put File Diagnostics Prompt in New Agent",
			},
		},
		cond = not_vscode,
	},
}
