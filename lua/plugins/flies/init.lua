local reverse = require("my.parameters").reverse
local edit = require("my.parameters").domain.edit
local move = require("my.parameters").domain.move
local theme = require("my.parameters").theme

return {
	{
		"prncss-xyz/flies.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			{
				"phaazon/hop.nvim",
				commit = "1a1ecea",
				module = "hop",
				opts = {
					jump_on_sole_occurrence = true,
				},
			},
		},
		config = function()
			require("flies").setup({
				hlslens = require("my.conds").not_vscode,
				op = {
					wrap = {
						chars = require("plugins.flies.chars"),
					},
				},
				hint_keys = require("my.parameters").selection_chars,
				mappings = {
					a = "toggle",
					b = require("flies.flies.brackets"),
					c = require("flies.flies.char_to_any"),
					d = require("flies.flies.line"),
					e = require("flies.flies.buffer"),
					f = "right",
					g = "left",
					i = require("flies.flies._ts"):new({ names = "conditional" }),
					j = require("flies.flies._ts"):new({ names = "block" }),
					k = require("flies.flies._ts"):new({ names = "call" }),
					l = require("flies.flies._ts"):new({ names = "loop" }),
					r = require("flies.flies.number"),
					n = "forward",
					o = require("flies.flies._ts"):new({
						names = "argument",
						use_context = true,
						ctx_pre = false,
					}),
					p = "backward",
					q = require("flies.flies.quote"),
					Q = require("flies.flies._ts"):new({
						names = "string",
						no_tree = require("flies.flies.quote"),
						nested = true,
					}),
					-- r: reference
					s = "hint",
					t = require("flies.flies._ts"):new({ names = "tag" }),
					-- u ...........................................
					v = require("flies.flies.variable_segment"),
					w = require("flies.flies.word"),
					x = require("flies.flies.dot_segment"),
					y = require("flies.flies._ts"):new({
						names = { "function", "section" },
						op = {
							wrap = { snip = true },
						},
					}),
					z = require("flies.flies.diagnostic"),
					["<"] = require("flies.flies.brackets"):new({
						left_patterns = { "<" },
						right_patterns = { ">" },
					}),
					["$"] = "last",
					[" "] = require("flies.flies.bigword"),
					["*"] = require("flies.flies._ts"):new({
						names = "comment",
						nested = false,
						lonely_wiseness_inner = "v",
						lonely_wiseness_outer = "V",
					}),
					["é"] = require("flies.flies.search"),
					-- ['<tab>']
				},
			})
		end,
		keys = {
			{
				"c",
				function()
					require("flies.operations.act").exec({
						around = "never",
					}, false, '"_c')
				end,
				desc = "Cut Void",
			},
			{
				"d",
				function()
					require("flies.operations.act").exec({
						domain = "outer",
						around = "always",
					}, false, '"_d')
				end,
				desc = "Delete Void",
			},
			{
				"e",
				function()
					require("flies.actions.move").move("n", {
						domain = "outer",
						move = "right",
					})
				end,
				mode = {
					"n",
					"x",
				},
				desc = "Move Right",
			},
			{
				"f",
				function()
					require("flies.actions.move").move("n", {
						axis = "forward",
						move = "left",
						domain = "outer",
					}, {
						pr = function()
							require("flies.actions.move_again").recompose2(function()
								require("illuminate").goto_prev_reference(true)
							end, function()
								require("illuminate").goto_next_reference(true)
							end, false)
						end,
						r = function()
							require("flies.actions.move_again").recompose2(function()
								require("illuminate").goto_prev_reference(true)
							end, function()
								require("illuminate").goto_next_reference(true)
							end, true)
						end,
					})
				end,
				mode = { "n" },
				desc = "Move Forward",
			},
			{
				"f",
				function()
					require("flies.actions.move").move("o", { axis = "forward", domain = "outer" })
				end,
				mode = { "o" },
				desc = "Move Forward",
			},
			{
				"f",
				function()
					require("flies.actions.move").move("x", { axis = "forward", domain = "outer" })
				end,
				mode = { "x" },
				desc = "Move Forward",
			},
			{
				"n",
				function()
					require("flies.actions.move_again").next()
				end,
				mode = {
					"n",
					"x",
				},
				desc = "Move Again Next",
			},
			{
				"p",
				function()
					require("flies.actions.move_again").prev()
				end,
				mode = {
					"n",
					"x",
				},
				desc = "Move Again Next",
			},
			{
				"s",
				function()
					require("flies.actions.move").move("n", { axis = "hint", domain = "outer" })
				end,
				desc = "Move Hint",
			},
			{
				"s",
				function()
					require("flies.actions.move").move("x", { axis = "hint", domain = "outer" })
				end,
				mode = { "x" },
				desc = "Move Hint",
			},
			{
				"v",
				function()
					require("flies.actions.select").select({
						domain = "outer",
						around = "always",
					})
				end,
				desc = "Select",
			},
			{
				"w",
				function()
					require("flies.actions.move").move("n", {
						domain = "outer",
						around = "never",
						move = "left",
					})
				end,
				mode = {
					"n",
					"x",
				},
				desc = "Move Left",
			},
			{
				"y",
				function()
					require("flies.operations.act").exec({
						domain = "outer",
						around = "never",
					}, nil, "y")
				end,
				desc = "Yank",
			},
			{
				edit .. reverse("a"),
				function()
					require("flies.ioperations.dial").descend:exec()
				end,
				desc = "Dial Prev",
			},
			{
				edit .. "a",
				function()
					require("flies.ioperations.dial").ascend:exec()
				end,
				desc = "Dial Next",
			},
			{
				edit .. "c",
				function()
					require("flies.operations.act").exec({ around = "never" }, false, "c")
				end,
				desc = "Cut",
			},
			{
				edit .. "d",
				function()
					require("flies.operations.act").exec({
						domain = "outer",
						around = "always",
					}, false, "d")
				end,
				desc = "Delete",
			},
			{
				edit .. "e",
				function()
					require("flies.operations.swap").exec("n")
				end,
				desc = "Exchange (Swap)",
			},
			{
				edit .. "w",
				function()
					require("flies.ioperations.toggle"):exec()
				end,
				desc = "Open-Close",
			},
			{
				edit .. "x",
				function()
					require("flies.operations.explode"):call()
				end,
				mode = { "n", "x" },
				desc = "Explode",
			},
			{
				edit .. "y",
				function()
					require("flies.operations.wrap"):call()
				end,
				mode = { "n", "x" },
				desc = "Wrap",
			},
			{
				edit .. theme.diagnostic,
				function()
					require("flies.operations.substitute"):call()
				end,
				desc = "Substitute",
			},
			{
				move .. "c",
				function()
					require("flies.flies.search").set_search(true)
					vim.cmd("normal! *N")
				end,
				mode = {
					"n",
				},
				desc = "Search Current Word",
			},
			{
				move .. "c",
				function()
					require("flies.flies.search").set_search(true)
					vim.cmd("normal! *N")
				end,
				mode = {
					"x",
				},
				desc = "Search Current Selection",
			},
			{
				"<c-a>",
				function()
					require("flies.flies.line"):move({
						axis = "best",
						domain = "outer",
						move = "left",
					})
				end,
				mode = { "n", "i", "c" },
				desc = "Move Begin of Line",
			},
			--[[
			{
				"<c-e>",
				function()
					require("flies.flies.line"):move({
						axis = "best",
						domain = "outer",
						move = "right",
					})
				end,
				mode = { "n", "i", "c" },
				desc = "Move End of Line",
			},
      --]]
			{
				"<m-b>",
				function()
					require("flies.flies.word"):move({
						axis = "backward",
						domain = "outer",
					})
				end,
				mode = { "n", "i", "c" },
				desc = "Move Word Backward",
			},
			{
				"<m-f>",
				function()
					require("flies.flies.word"):move({
						axis = "forward",
						domain = "outer",
					})
				end,
				mode = { "n", "i", "c" },
				desc = "Move Word Forward",
			},
		},
	},
}
