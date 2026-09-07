local personal = require("my.conds").personal
local work = require("my.conds").work
local not_vscode = require("my.conds").not_vscode
local reverse = require("my.parameters").reverse
local theme = require("my.parameters").theme
local domain = require("my.parameters").domain
local file = domain.file
local pick = domain.pick
local win = domain.win
local web = domain.web
local move = domain.move
local git = domain.git
local projects = require("plugins.snacks.projects")
local auto_confirm = require("plugins.snacks.auto_confirm")
local create_file = require("plugins.snacks.create_file")
local dirs = require("my.parameters").dirs

return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		---@type snacks.Config
		opts = function()
			return {
				image = work({ doc = { enabled = true } }),
				bigfile = { enabled = true },
				indent = { enabled = true },
				input = { enabled = true },
				picker = {
					auto_confirm = true,
					config = auto_confirm.config,
					enabled = true,
					actions = {
						create_file = {
							action = create_file.create,
							desc = "create file",
						},
						use_focused_path = {
							action = create_file.use_focused_path,
							desc = "use focused path",
						},
						open_project = {
							action = function(picker)
								local cwd = vim.fn.getcwd()
								picker:close()
								projects.open_project(cwd)
							end,
							desc = "open_project",
						},
						trouble_open = {
							action = function(picker)
								require("my.ui_toggle").activate("trouble", function()
									require("trouble.sources.snacks").open(picker, { type = "smart" })
								end)
							end,
							desc = "trouble open",
						},
					},
					win = {
						input = {
							keys = {
								["<c-cr>"] = { "create_file", mode = { "n", "i" } },
								["<c-g>"] = { "use_focused_path", mode = { "n", "i" } },
								["<c-u>"] = { "<c-u>", mode = { "i" }, expr = true, desc = "delete line before" },
								["<c-t>"] = {
									"trouble_open",
									mode = { "n", "i" },
								},
							},
						},
					},
				},
				notifier = { enabled = true },
				quickfile = { enabled = true },
				scope = { enabled = true },
				statuscolumn = { enabled = false },
				words = { enabled = true },
			}
		end,
		keys = {
			{
				web .. theme.hunk,
				function()
					Snacks.gitbrowse.open()
				end,
				desc = "Browse Git Remote",
			},
			{
				domain.appearance .. "d",
				function()
					if Snacks.dim.enabled then
						Snacks.dim.disable()
					else
						Snacks.dim.enable()
					end
				end,
				desc = "Window Dim",
			},
			{
				win .. "x",
				function()
					Snacks.bufdelete.delete()
				end,
				desc = "Window Bufdelete",
			},
			{
				win .. theme.scratch,
				function()
					Snacks.scratch.open()
				end,
				desc = "Scratch Open",
			},
			{
				pick .. theme.buffers,
				function()
					Snacks.picker.buffers({
						transform = require("plugins.snacks.transform").exclude_current(),
					})
				end,
				desc = "Pick Buffer",
			},
			{
				pick .. reverse(theme.buffers),
				function()
					-- TODO: I would like this to list all working dirictories of opened projects
					-- and pick would open a buffer (the most recently accessed) of one of them
					projects.pick_project()
				end,
				desc = "Pick Opened Project",
			},
			{
				pick .. reverse(theme.project),
				function()
					projects.pick_worktree()
				end,
				desc = "Pick Worktree",
			},
			{
				pick .. theme.project,
				function()
					projects.pick_project()
				end,
				desc = "Pick Project",
			},
			{
				pick .. theme.definition,
				function()
					Snacks.picker.lsp_definitions()
				end,
				desc = "Goto Definition",
			},
			{
				pick .. "e",
				function()
					Snacks.picker.smart({
						transform = require("plugins.snacks.transform").file(),
					})
				end,
				desc = "Pick Smart File",
			},
			{
				pick .. "n",
				function()
					Snacks.picker.files({
						cwd = dirs.notes,
						matcher = {
							frecency = true,
						},
						args = { "-e", "md" },
					})
				end,
				desc = "Pick Note File",
			},
			{
				pick .. reverse("n"),
				function()
					Snacks.picker.files({
						cwd = dirs.artifacts,
						matcher = {
							frecency = true,
						},
						args = { "-e", "md" },
					})
				end,
				desc = "Pick Any Artifact File",
			},
			{
				file .. "l",
				projects.pick_current_lang_note,
				desc = "Edit Lang Note",
			},
			{
				pick .. ",",
				function()
					Snacks.picker.files({
						cwd = vim.fn.stdpath("config"),
						matcher = {
							frecency = true,
						},
					})
				end,
				desc = "Pick Config File",
			},
			{
				pick .. ".",
				function()
					if personal() then
						Snacks.picker.files({
							cwd = dirs.dotfiles,
							matcher = {
								frecency = true,
							},
						})
					end
				end,
				desc = "Pick Dotifiles",
			},
			{
				pick .. theme.directory,
				function()
					-- like unique_file, but removes current file
					local name = vim.api.nvim_buf_get_name(0)
					Snacks.picker.files({
						cwd = vim.fn.expand("%:h"),
						transform = function(item, ctx)
							ctx.meta.done = ctx.meta.done or {} ---@type table<string, boolean>
							local path = Snacks.picker.util.path(item)
							if not path or path == name or path == ctx.meta.current or ctx.meta.done[path] then
								return false
							end
							ctx.meta.done[path] = true
						end,
					})
				end,
				desc = "Pick File",
			},
			{
				domain.appearance .. pick,
				function()
					Snacks.picker.colorschemes()
				end,
				desc = "Pick Colorscheme",
			},
			{
				pick .. theme.hunk,
				function()
					Snacks.picker.pick({
						---@diagnostic disable-next-line: unused-local
						finder = function(opts, ctx)
							return require("snacks.picker.source.proc").proc(
								ctx:opts({
									cmd = "git",
									args = { "ls-files", "-mo", "--exclude-standard" },
									transform = require("plugins.snacks.transform").hunk(),
								}),
								ctx
							)
						end,
						format = "file",
						title = "Diff Files",
						matcher = {
							cwd_bonus = true,
							frecency = true,
							sort_empty = true,
						},
						transform = require("plugins.snacks.transform").modified(),
					})
				end,
				desc = "Pick Diff Files",
			},
			{
				pick .. "i",
				function()
					Snacks.picker.notifications()
				end,
				desc = "Pick Notification",
			},
			{
				pick .. "a",
				function()
					Snacks.picker.files({ cwd = dirs.artifacts })
				end,
				desc = "Pick Artifact File",
			},
			{
				pick .. reverse("a"),
				function()
					local project_dir = require("plugins.toggleterm.terms.artifact_cwd").context_dir()
						or vim.fn.getcwd()
					local branch = vim.trim(vim.fn.system({ "git", "-C", project_dir, "branch", "--show-current" }))
					assert(vim.v.shell_error == 0 and branch ~= "", "Failed to determine current Git branch")
					local artifacts_dir = vim.fs.joinpath(project_dir, ".artifacts")
					if branch ~= "main" then
						artifacts_dir = vim.fs.joinpath(artifacts_dir, (branch:gsub("/", "-")))
					end
					Snacks.picker.files({ cwd = artifacts_dir })
				end,
				desc = "Pick Branch Artifact File",
			},
			{
				pick .. theme.find,
				function()
					Snacks.picker.lines()
				end,
				desc = "Pick Search line",
			},
			{
				pick .. "m",
				function()
					Snacks.picker.marks()
				end,
				desc = "Pick Mark",
			},
			{
				pick .. theme.scratch,
				function()
					Snacks.scratch.select()
				end,
				desc = "Scratch Open",
			},
			{
				pick .. "q",
				function()
					Snacks.picker.qflist()
				end,
				desc = "Pick QFlist",
			},
			{
				pick .. theme.reference,
				function()
					Snacks.picker.lsp_references()
				end,
				desc = "Goto References",
			},
			{
				pick .. theme.symbol,
				function()
					if vim.bo.filetype == "markdown" then
						Snacks.picker.lsp_symbols()
					else
						Snacks.picker.lsp_symbols()
					end
				end,
				desc = "Pick Symbols",
			},
			{
				pick .. theme.work,
				function()
					---@diagnostic disable-next-line: undefined-field
					Snacks.picker.todo_comments()
				end,
				desc = "Pick Todo Comment",
			},
			{
				pick .. theme.diagnostic,
				function()
					Snacks.picker.diagnostics()
				end,
				desc = "Goto Diagnostic",
			},
			{
				pick .. "g",
				function()
					Snacks.picker.grep({ regex = false })
				end,
				desc = "Live Grep",
			},
			{
				pick .. reverse("g"),
				function()
					Snacks.picker.grep({ regex = false, cwd = vim.fn.expand("%:p:h") })
				end,
				desc = "Live Grep Local",
			},
			{
				pick .. "g",
				function()
					Snacks.picker.grep_word({ regex = false })
				end,
				mode = { "x" },
				desc = "Live Grep",
			},
			{
				pick .. pick,
				function()
					Snacks.picker.keymaps({
						format = require("plugins.snacks.format").keymap,
					})
				end,
				desc = "Keymaps",
			},
			{
				pick .. reverse(pick),
				function()
					Snacks.picker.pickers()
				end,
				desc = "Pick Picker",
			},
			{
				git .. "b",
				function()
					Snacks.picker.git_branches()
				end,
				desc = "Pick Branch",
			},
			{
				git .. "r",
				function()
					Snacks.picker.gh_pr()
				end,
				desc = "Pick GitHub PR",
			},
			{
				git .. "y",
				function()
					Snacks.gitbrowse()
				end,
				desc = "Git Browse",
			},
			{
				pick .. "o",
				function()
					Snacks.picker.recent({ filter = { cwd = true } })
				end,
				desc = "Pick Oldfiles",
			},
			{
				pick .. reverse("o"),
				function()
					Snacks.picker.recent()
				end,
				desc = "Pick Oldfiles",
			},
			{
				pick .. "x",
				function()
					Snacks.picker.zoxide()
				end,
				desc = "Pick Zoxide",
			},
			{
				"oxu",
				function()
					Snacks.picker.undo()
				end,
				desc = "Pick Undo History",
			},
			{
				move .. theme.project,
				projects.toggle_project,
				desc = "Toggle Project",
			},
			{
				move .. "e",
				projects.toggle_file,
				desc = "Toggle File",
			},
			{
				"bz",
				function()
					if require("my.windows").is_file_cur_win then
						projects.open_project(vim.env.HOME, {
							vim.fn.getcwd(),
							require("my.parameters").dirs.notes,
							require("my.parameters").dirs.dotfiles,
							vim.fn.stdpath("config"),
						})
					end
				end,
				desc = "Open Last Project ",
			},
			{
				"bn",
				function()
					local project_dir =
						require("plugins.toggleterm.terms.artifact_cwd").resolve(vim.api.nvim_buf_get_name(0))
					if project_dir then
						require("plugins.toggleterm.terms.ensure_dir").open_dir(project_dir, 0, false)
					else
						projects.open_project(require("my.parameters").dirs.notes)
					end
				end,
				desc = "Open Notes Dir",
			},
			{
				"b.",
				function()
					projects.open_project(require("my.parameters").dirs.dotfiles)
				end,
				desc = "Open Notes Dir",
			},
			{
				"b,",
				function()
					projects.open_project(vim.fn.stdpath("config"))
				end,
				desc = "Open Notes Dir",
			},
		},
		cond = not_vscode,
	},
	{
		"DestopLine/scratch-runner.nvim",
		dependencies = { "folke/snacks.nvim" },
		lazy = false,
		opts = {
			sources = {
				javascript = { "deno" }, -- Your options go here
				typescript = { "deno" }, -- Your options go here
				javascriptreact = { "deno" }, -- Your options go here
				typescriptreact = { "deno" }, -- Your options go here
			},
		},
		enabled = personal,
		cond = not_vscode,
	},
}
