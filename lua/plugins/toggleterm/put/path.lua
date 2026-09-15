local M = {}

---@param filename string
---@return string
function M.display(filename)
	local absolute = vim.fs.abspath(filename)
	if not require("plugins.toggleterm.terms.artifact_cwd").contains(absolute) then
		return vim.fn.fnamemodify(absolute, ":.")
	end

	local relative = vim.fs.relpath(vim.env.HOME, absolute)
	if relative then
		return relative == "." and "~" or "~/" .. relative
	end

	return absolute
end

return M
