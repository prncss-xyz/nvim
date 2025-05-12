local domain = require("my.parameters").domain
local reverse = require("my.parameters").reverse

return {
	{
		"prncss-xyz/khutulun.nvim",
		-- 'chrisgrieser/nvim-genghis',
		opts = {
			move = function(source, target)
				Snacks.rename.rename_file({
					from = source,
					to = target,
				})
			end,
			bdelete = function()
				Snacks.bufdelete.delete()
			end,
		},
		keys = {
			{
				domain.file .. "d",
				function()
					require("khutulun").duplicate()
				end,
				desc = "Duplicate File",
			},
			{
				domain.file .. "e",
				function()
					require("khutulun").create()
				end,
				desc = "New File",
			},
			{
				domain.file .. "e",
				function()
					require("khutulun").create()
				end,
				mode = { "x" },
				desc = "New File From Selection",
			},
			{
				domain.file .. "r",
				function()
					require("khutulun").rename()
				end,
				desc = "Rename File",
			},
			{
				domain.file .. "v",
				function()
					require("khutulun").move()
				end,
				desc = "Move File",
			},
			{
				domain.file .. "w",
				"!wc %",
				desc = "Word Count",
			},
			{
				domain.file .. "x",
				function()
					require("khutulun").delete()
				end,
				desc = "Delete File",
			},
			{
				domain.file .. "yl",
				function()
					require("khutulun").yank_filename()
				end,
				desc = "Yank Filename",
			},
			{
				domain.file .. "yr",
				function()
					require("khutulun").yank_relative_path()
				end,
				desc = "Yank Relative Filepath",
			},
			{
				domain.file .. "ya",
				function()
					require("khutulun").yank_absolute_path()
				end,
				desc = "Yank Absolute Filepath",
			},
			{
				domain.move .. reverse("d"),
				function()
					require("flies.actions.move_again").recompose2(
						"<Plug>(unimpaired-directory-previous)",
						"<Plug>(unimpaired-directory-next)",
						false
					)
				end,
				desc = "Previous Directory File",
			},
			{
				domain.move .. "d",
				function()
					require("flies.actions.move_again").recompose2(
						"<Plug>(unimpaired-directory-previous)",
						"<Plug>(unimpaired-directory-next)",
						true
					)
				end,
				desc = "Next Directory File",
			},
		},
	},
}
