vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		local client = vim.lsp.get_client_by_id(args.data.client_id)
		if client.server_capabilities.codeLensProvider then
			-- Refresh codelens on initial attach
			require("my.hints").refresh()
			-- could use VidocqH/lsp-lens.nvim to reduce flicker
			-- Auto-refresh on buffer entry and when leaving insert mode
			vim.api.nvim_create_autocmd({ "BufWritePost" }, {
				buffer = args.buf,
				callback = function()
					vim.lsp.codelens.refresh({ bufnr = args.buf })
				end,
			})
		end
	end,
})
