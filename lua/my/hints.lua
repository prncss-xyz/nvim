local M = {}

local hints = false

function M.toggle()
	hints = not hints
	vim.lsp.inlay_hint.enable(hints)
	-- Neovim 0.12+: codelens is enabled per-buffer via vim.lsp.codelens.enable()
	-- No need for manual refresh - it auto-refreshes when enabled
	vim.lsp.codelens.enable(hints)
end

return M
