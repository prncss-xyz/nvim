local edit = require("my.parameters").domain.edit
local win = require("my.parameters").domain.win
local theme = require("my.parameters").theme
local personal = require("my.conds").personal

local engine = "rigrep"
-- local engine = "astgrep"

return {
	{
		"MagicDuck/grug-far.nvim",
		opts = {},
		cmd = { "GrugFar" },
		keys = {
			{
				win .. theme.find,
				function()
					require("my.ui_toggle").activate("grugfar", function()
						require("grug-far").open({ engine = engine })
					end)
				end,
				desc = "GrugFar",
			},
			{
				win .. theme.find,
				function()
					require("my.ui_toggle").activate("grugfar", function()
						require("grug-far").with_visual_selection({ engine = engine })
					end)
				end,
				mode = { "x" },
				desc = "GrugFar",
			},
		},
	},
	{
		"ThePrimeagen/refactoring.nvim",
		dependencies = {
			{ "nvim-lua/plenary.nvim" },
			{ "nvim-treesitter/nvim-treesitter" },
		},
		opts = {},
	},
	{
		"danymat/neogen",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		opts = {
			snippet_engine = "luasnip",
			languages = {
				typescript = {
					template = {
						annotation_convention = "tsdoc",
					},
				},
				typescriptreact = {
					template = {
						annotation_convention = "tsdoc",
					},
				},
			},
		},
		keys = {
			{
				edit .. "ny",
				function()
					require("neogen").generate({
						type = "func",
					})
				end,
				desc = "Annotate Function",
			},
			{
				edit .. "nk",
				function()
					require("neogen").generate({
						type = "class",
					})
				end,
				desc = "Annotate Class",
			},
			{
				edit .. "nt",
				function()
					require("neogen").generate({
						type = "type",
					})
				end,
				desc = "Annotate Type",
			},
			{
				edit .. "nf",
				function()
					require("neogen").generate({
						type = "file",
					})
				end,
				desc = "Annotate File",
			},
		},
		enabled = personal,
	},
	{
		-- FIX: toggle block seeams not to work with certain syntaxes unless toggle multiline was called before
		-- likely due to breaking changes in treesitter
		"Wansmer/treesj",
		lazy = false,
		opts = {
			use_default_keymaps = false,
		},
		cmd = { "TSJToggle", "TSJSplit", "TSJJoin" },
		keys = {
			{
				edit .. "g",
				function()
					require("treesj").toggle()
				end,
				desc = "TSJToggle",
			},
		},
	},
}
