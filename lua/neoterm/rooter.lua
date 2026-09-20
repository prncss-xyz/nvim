local M = {}

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

	local root = get_root(0)
	if root then
		vim.api.nvim_set_current_dir(root)
	end
end

return M
