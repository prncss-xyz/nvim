local edit = require("my.parameters").domain.edit
local pane = require("my.parameters").domain.pane
local theme = require("my.parameters").theme
local personal = require("my.conds").personal

return {
	{
		"MagicDuck/grug-far.nvim",
		opts = {},
		cmd = { "GrugFar" },
		keys = {
			{
				pane .. theme.find,
				"<cmd>GrugFar<cr>",
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
				desc = "annotate function",
			},
			{
				edit .. "nk",
				function()
					require("neogen").generate({
						type = "class",
					})
				end,
				desc = "annotate function",
			},
			{
				edit .. "nt",
				function()
					require("neogen").generate({
						type = "type",
					})
				end,
				desc = "annotate function",
			},
			{
				edit .. "nf",
				function()
					require("neogen").generate({
						type = "file",
					})
				end,
				desc = "annotate function",
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
			{
				edit .. "nf",
				function()
					require("treesj").toggle()
				end,
				desc = "caca",
			},
		},
	},
}
