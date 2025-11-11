local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

return {
	{
		"Kaiser-Yang/blink-cmp-avante",
		cond = personal,
	},
	{
		"saghen/blink.cmp",
		dependencies = {
			personal({
				"L3MON4D3/LuaSnip",
				"Kaiser-Yang/blink-cmp-avante",
			}, {
				"L3MON4D3/LuaSnip",
			}),
		},
		version = "*",
		opts = {
			keymap = {
				preset = "none",
				["<c-p>"] = { "show", "select_prev", "fallback" },
				["<c-n>"] = { "show", "select_next", "fallback" },
				["<c-g>"] = { "accept", "fallback" },
				["<tab>"] = {
					"snippet_forward",
					function()
						if package.loaded["sidekick"] then
							return require("sidekick").nes_jump_or_apply()
						end
					end,
					"fallback",
				},
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
				default = personal({
					"avante",
					"lazydev",
					"lsp",
					"path",
					"snippets",
					"buffer",
				}, {
					"lazydev",
					"lsp",
					"path",
					"snippets",
					"buffer",
				}),
				providers = {
					snippets = {
						score_offset = 200,
					},
					buffer = {
						score_offset = -100,
					},
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
					path = {
						enabled = function()
							return vim.bo.filetype ~= "copilot-chat"
						end,
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
