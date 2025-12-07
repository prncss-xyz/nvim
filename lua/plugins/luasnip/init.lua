local snippets = require("my.parameters").domain.snippets

return {
	{
		"L3MON4D3/LuaSnip",
		opts = {
			history = false,
			enable_autosnippets = false,
			snip_env = require("plugins.luasnip.env"),
		},
		config = function(_, opts)
			local ls = require("luasnip")
			ls.config.set_config(opts)
			if true then
				ls.filetype_extend("mdx", { "markdown" })
				ls.filetype_extend("javascriptreact", { "javascript" })
				ls.filetype_extend("typescript", { "javascript" })
				ls.filetype_extend("typescriptreact", {
					"javascriptreact",
					-- 'typescript',
					"javascript",
				})
			end
			--FIX: hot reload not working
			require("luasnip.loaders.from_vscode").lazy_load({})
			require("luasnip.loaders.from_lua").lazy_load({})
		end,
		build = "make install_jsregexp",
		keys = {
			{
				snippets,
				function()
					require("luasnip.loaders").edit_snippet_files()
				end,
				desc = "edit snippets",
			},
		},
		cmd = "LuaSnipUnlinkCurrent",
	},
}
