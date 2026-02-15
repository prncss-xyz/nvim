local M = {}

local hints = false

function M.toggle()
	hints = not hints
	vim.lsp.inlay_hint.enable(hints)
	M.refresh()
end

function M.refresh()
	if hints then
		vim.lsp.codelens.refresh()
	end
end

return M
