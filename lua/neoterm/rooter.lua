local M = {}
local current_zone

local function get_root(path)
	return vim.fs.root(path, require("neoterm.config").rooter_patterns)
end

function M.project_dir(path)
	return get_root(path) or vim.fs.normalize(path)
end

function M.on_buf_enter()
	if vim.bo.buftype ~= "" then
		return
	end

	local path = vim.api.nvim_buf_get_name(0)
	if path == "" then
		return
	end

	local config = require("neoterm.config")
	local zone = require("neoterm.terms.artifacts.cwd").resolve(path) or get_root(path) or vim.fs.dirname(path)
	local root = get_root(0)
	if root then
		vim.api.nvim_set_current_dir(root)
	end

	if zone ~= current_zone then
		current_zone = zone
		if config.on_zone then
			config.on_zone(zone)
		end
	end
end

return M
