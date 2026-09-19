local M = {}

function M.root(path)
	return vim.fs.root(path, require("neoterm.config").rooter_patterns)
end

function M.project_dir(path)
	return M.root(path) or vim.fs.normalize(path)
end

local seen = {}

function M.on_dir()
	local config = require("neoterm.config")
	local terms = require("neoterm.terms")
	local cwd = vim.fn.getcwd()
	if seen[cwd] then
		return
	end
	seen[cwd] = true
	for _, v in ipairs(config.autostart) do
		terms.prepare(v)
	end
end

return M
