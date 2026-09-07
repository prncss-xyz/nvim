local M = {}

function M.root(path)
	return vim.fs.root(path, require("my.parameters").rooter_patterns)
end

function M.project_dir(path)
	return M.root(path) or vim.fs.normalize(path)
end

return M
