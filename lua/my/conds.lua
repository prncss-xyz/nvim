local M = {}

function M.personal()
	return vim.env.HOME == "/home/prncss"
end

function M.not_vscode()
	return not vim.g.vscode
end

return M
