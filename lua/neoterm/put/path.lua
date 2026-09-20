local M = {}

---@param path string
---@return string
function M.home_relative(path)
	local home = vim.fs.normalize(vim.env.HOME)
	path = vim.fs.normalize(path)
	local relative = vim.fs.relpath(home, path)
	if relative then
		return relative == "." and "~" or "~/" .. relative
	end
	return path
end

---@param path string
---@return string
function M.format(path)
	if path:find("[^%w%._/%-~]") then
		return string.format("%q", path)
	end
	return path
end

---@param filename string
---@return string
function M.display(filename)
	local absolute = vim.fs.abspath(filename)
	if not require("neoterm.terms.artifacts.cwd").contains(absolute) then
		return vim.fn.fnamemodify(absolute, ":.")
	end

	return M.home_relative(absolute)
end

return M
