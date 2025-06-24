local not_vscode = require("my.conds").not_vscode

return {
	{
		"saghen/blink.cmp",
		dependencies = {
			{
				"L3MON4D3/LuaSnip",
				"Kaiser-Yang/blink-cmp-avante",
			},
		},
		version = "*",
		opts = {
			keymap = {
				preset = "none",
				["<c-p>"] = { "show", "select_prev", "fallback" },
				["<c-n>"] = { "show", "select_next", "fallback" },
				["<c-g>"] = { "accept", "fallback" },
			},
			snippets = { preset = "luasnip" },
			completion = {
				accept = {
					auto_brackets = {
						enabled = false,
					},
				},
			},
			sources = {
				default = {
					"avante",
					"lazydev",
					"lsp",
					"path",
					"snippets",
					"buffer",
				},
				providers = {
					lazydev = {
						name = "LazyDev",
						module = "lazydev.integrations.blink",
						score_offset = 100,
					},
					avante = {
						module = "blink-cmp-avante",
						name = "Avante",
						opts = {},
					},
				},
			},
		},
		event = "InsertEnter",
		cond = not_vscode,
	},
	{
		"windwp/nvim-autopairs",
		opts = {
			disable_in_macro = true,
			-- check_ts = true,
			fast_wrap = {
				map = "<m-p>",
				chars = { "{", "[", "(", '"', "'" },
				pattern = string.gsub([[ [%'%"%)%>%]%)%}%,] ]], "%s+", ""),
				end_key = ";",
				keys = "qwertyuiopzxcvbnmasdfghjkl",
				check_comma = true,
			},
		},
		event = "InsertEnter",
		cond = not_vscode,
	},
	-- Use tressitter to autoclose and autorename HTML tag
	{
		"windwp/nvim-ts-autotag",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		opts = {},
		event = "InsertEnter",
		cond = not_vscode,
		ft = { "html", "javascriptreact", "typescriptreact", "javascript", "markdown" },
	},
}
