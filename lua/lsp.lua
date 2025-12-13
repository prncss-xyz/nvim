for _, lsp in pairs({
	"bashls",
	"gopls",
	"marksman",
	-- "eslint",
}) do
	vim.lsp.config(lsp, {
		capabilities = require("plugins.lsp.utils").cmp_capabilities,
	})
end
vim.lsp.config("graphql", {
	capabilities = require("plugins.lsp.utils").cmp_capabilities,
	filetypes = { "graphql", "javascript", "typescript", "javascriptreact", "typescriptreact" },
})
vim.lsp.config("lua_ls", {
	capabilities = require("plugins.lualine").cmp_capabilities,
	settings = {
		Lua = {
			telemetry = {
				enabled = false,
			},
		},
	},
})
vim.lsp.config("ltex-ls-plus", {
	capabilities = require("plugins.lualine").cmp_capabilities,
	load_langs = { "en-US", "fr" },
	settings = {
		ltex = {
			enabled = { "markdown" },
			language = "auto",
			additionalRules = {
				enablePickyRules = true,
			},
			disabledRules = {
				en = {
					"UPPERCASE_SENTENCE_START",
					"PUNCTUATION_PARAGRAPH_END",
				},
				fr = {
					"APOS_TYP",
					"FRENCH_WHITESPACE",
					"UPPERCASE_SENTENCE_START",
					"PUNCTUATION_PARAGRAPH_END",
				},
			},
		},
	},
})

vim.lsp.enable({
	"bashls",
	"gopls",
	"marksman",
	-- "eslint",
	"graphql",
	"lua_ls",
	"ltex_plus",
})
