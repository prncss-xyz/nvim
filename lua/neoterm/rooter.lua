local M = {}

local function get_root(path)
	return vim.fs.root(path, require("neoterm.config").rooter_patterns)
end

function M.project_dir(path)
	return get_root(path) or vim.fs.normalize(path)
end

local seen = {}

function M.on_buf_enter()
	if vim.bo.buftype ~= "" then
		return
	end

	local root = get_root(0)
	if root then
		vim.api.nvim_set_current_dir(root)
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
end

return M
