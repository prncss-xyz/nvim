local edit = require("my.parameters").domain.edit
local comment = require("my.parameters").theme.comment
local reverse = require("my.parameters").reverse

return {
	{
		"JoosepAlviste/nvim-ts-context-commentstring",
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		opts = {},
		event = "VeryLazy",
	},
	{
		"numToStr/Comment.nvim",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
		},
		opts = function()
			return {
				mappings = false,
			}
		end,
		config = function(_, opts)
			opts.pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook()
			local ft = require("Comment.ft")
			ft.set("sway", "#%s")
			require("Comment").setup(opts)
		end,
		keys = {
			{
				edit .. reverse(comment),
				function()
					require("flies.operations.act").exec({
						domain = "outer",
						around = "always",
					}, false, "<plug>(comment_toggle_blockwise)")
				end,
				desc = "Toggle Comment Blockwise",
			},
			{
				edit .. reverse(comment),
				"<plug>(comment_toggle_blockwise_visual)",
				mode = { "x" },
				desc = "Toggle Comment Blockwise",
			},
			{
				edit .. comment,
				function()
					require("flies.operations.act").exec(
						{
							domain = "outer",
							around = "always",
						},
						{
							gg = function()
								local config = require("Comment.config"):get()
								require("Comment.api").insert.linewise.above(config)
							end,
							ff = function()
								local config = require("Comment.config"):get()
								require("Comment.api").insert.linewise.eol(config)
							end,
						},
						function()
							require("Comment.api").comment.linewise.current()
						end
						--  "<plug>(comment_linewise_blockwise)"
					)
				end,
				desc = "Toggle Comment Linewise",
			},
			{
				edit .. comment,
				"<plug>(comment_toggle_linewise_visual)",
				mode = { "x" },
				desc = "Toggle Comment Linewise",
			},
		},
	},
}
