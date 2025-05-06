local personal = require("my.conds").personal
local not_vscode = require("my.conds").not_vscode
local reverse = require("my.parameters").reverse
local theme = require("my.parameters").theme
local domain = require("my.parameters").domain
local pane = domain.pane
local pick = domain.pick
local win = domain.win
local web = domain.web

return {
	{
		"folke/snacks.nvim",
		priority = 1000,
		lazy = false,
		---@type snacks.Config
		opts = function()
			local actions = require("my.tables").deep_merge({
				open_project = {
					action = function(picker)
						local cwd = vim.fn.getcwd()
						picker:close()
						require("my.open_project").open_project(cwd)
					end,
					desc = "open_project",
				},
			}, require("trouble.sources.snacks").actions)
			return {
				bigfile = { enabled = true },
				indent = { enabled = true },
				input = { enabled = true },
				picker = {
					enabled = true,
					actions = actions,
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
				win .. "d",
				function()
					Snacks.dim()
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
				pane .. theme.scratch,
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
				pick .. "c",
				function()
					Snacks.picker.pick({
						finder = "recent_projects",
						transform= require("plugins.snacks.transform").filter_current_dir(),
						format = "file",
						dev = { "~/dev", "~/projects" },
						confirm = "load_session",
						patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "package.json", "Makefile" },
						recent = true,
						matcher = {
							frecency = true,
							sort_empty = true,
							cwd_bonus = false,
						},
						sort = { fields = { "score:desc", "idx" } },
						win = {
							preview = { minimal = true },
							input = {
								keys = {
									-- every action will always first change the cwd of the current tabpage to the project
									["<c-e>"] = { { "tcd", "picker_explorer" }, mode = { "n", "i" } },
									["<c-f>"] = { { "tcd", "picker_files" }, mode = { "n", "i" } },
									["<c-g>"] = { { "tcd", "picker_grep" }, mode = { "n", "i" } },
									["<c-r>"] = { { "tcd", "picker_recent" }, mode = { "n", "i" } },
									["<c-w>"] = { { "tcd" }, mode = { "n", "i" } },
									["<c-t>"] = {
										function(picker)
											vim.cmd("tabnew")
											Snacks.notify("New tab opened")
											picker:close()
											Snacks.picker.projects()
										end,
										mode = { "n", "i" },
									},
									["<cr>"] = { { "tcd", "open_project" }, mode = { "n", "i" } },
								},
							},
						},
					})
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
						transform = require("plugins.snacks.transform").exclude_current(),
					})
				end,
				desc = "Pick Smart File",
			},
			{
				pick .. theme.file,
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
					Snacks.picker.git_diff()
				end,
				desc = "Pick Diff",
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
					Snacks.picker.lsp_symbols()
				end,
				desc = "Pick LSP Symbols",
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
				"oxu",
				function()
					Snacks.pickers.undo()
				end,
				desc = "Undo History",
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
