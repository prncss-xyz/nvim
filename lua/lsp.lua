for _, lsp in pairs({
	"bashls",
	"gopls",
	"oxlint",
	"typos_lsp",
}) do
	vim.lsp.config(lsp, {
		capabilities = require("plugins.lsp.utils").cmp_capabilities,
	})
end

-- not working well with voidlinux
vim.lsp.config("marksman", {
	cmd = { "marksman", "server" },
	filetypes = { "markdown", "markdown.mdx" },
	root_markers = { ".marksman.toml", ".git" },
	capabilities = require("plugins.lsp.utils").cmp_capabilities,
})

vim.lsp.config("tsgo", {
	cmd = { "tsgo", "--lsp", "--stdio" },
	root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
	capabilities = require("plugins.lsp.utils").cmp_capabilities,
	settings = {
		typescript = {
			updateImportsOnFileMove = { enabled = "always" },
			suggest = { completeFunctionCalls = true },
			inlayHints = {
				parameterNames = { enabled = "all" },
				parameterTypes = { enabled = true },
				variableTypes = { enabled = true },
				propertyDeclarationTypes = { enabled = true },
				functionLikeReturnTypes = { enabled = true },
				enumMemberValues = { enabled = true },
			},
		},
	},
})

vim.lsp.config("markdown_oxide", {
	cmd = { "markdown-oxide" },
	filetypes = { "markdown" },
	root_markers = { ".git", ".obsidian", ".moxide.toml" },
	capabilities = require("plugins.lsp.utils").get_cmp_capabilities({
		workspace = {
			didChangeWatchedFiles = {
				dynamicRegistration = true,
			},
		},
	}),
})
vim.lsp.enable("markdown_oxide")

vim.lsp.config("graphql", {
	capabilities = require("plugins.lsp.utils").cmp_capabilities,
	filetypes = { "graphql", "javascript", "typescript", "javascriptreact", "typescriptreact" },
})

vim.lsp.config("oxfmt", {
	capabilities = require("plugins.lsp.utils").cmp_capabilities,
	filetypes = {
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
		"json",
		"jsonc",
		"json5",
		"markdown",
		"markdown.mdx",
		"yaml",
		"toml",
		"html",
		"css",
		"scss",
		"less",
		"vue",
		"svelte",
		"graphql",
	},
	root_markers = {
		".oxfmtrc.json",
		".oxfmtrc.jsonc",
		"oxfmt.config.ts",
		"package.json",
		".git",
	},
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
vim.lsp.config("ltex-ls", {
	capabilities = require("plugins.lualine").cmp_capabilities,
	load_langs = { "en-US", "fr" },
	on_attach = function()
		require("ltex_extra").setup({
			load_langs = { "en-US", "fr" },
			init_check = true,
		})
	end,
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
	"graphql",
	"knip",
	"lua_ls",
	"ltex",
	"oxlint",
	"oxfmt",
	"tsgo",
	"typos_lsp",
})
