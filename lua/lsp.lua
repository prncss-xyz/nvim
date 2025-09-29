for _, lsp in pairs({
	"bashls",
	"gopls",
	"marksman",
	"eslint",
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

vim.lsp.enable({
	"bashls",
	"gopls",
	"marksman",
	"eslint",
	"graphql",
	"lua_ls",
})
