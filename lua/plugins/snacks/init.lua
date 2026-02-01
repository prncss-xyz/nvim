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
local notes = require("my.parameters").dirs.notes

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
					enabled = true,
					actions = {
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
				scroll = { enabled = true },
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
					Snacks.dim()
				end,
				desc = "Window Dim",
			},
			{
				domain.appearance .. reverse("d"),
				function()
					Snacks.dim.disable()
				end,
				desc = "Window Un Dim",
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
				pick .. theme.project,
				projects.pick_project,
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
						cwd = notes,
						matcher = {
							frecency = true,
						},
						args = { "-e", "md" },
					})
				end,
				desc = "Pick Note File",
			},
			{
				file .. "l",
				projects.pick_current_lang_note,
				desc = "Edit Lang Note",
			},
			{
				file .. "n",
				projects.pick_current_project_note,
				desc = "Edit Project Note",
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
							cwd = vim.env.HOME .. "/.local/share/chezmoi",
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
					Snacks.picker.grep()
				end,
				desc = "Live Grep",
			},
			{
				pick .. "g",
				function()
					Snacks.picker.grep_word()
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
