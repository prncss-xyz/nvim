local M = {}

--- Get the indentation unit (tab or spaces based on buffer settings)
---@return string
function M.get_indent_unit()
	local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", {})
	if shiftwidth == 0 then
		shiftwidth = vim.api.nvim_get_option_value("tabstop", {})
	end
	local expandtab = vim.api.nvim_get_option_value("expandtab", {})
	return expandtab and string.rep(" ", shiftwidth) or "\t"
end

--- Get the leading whitespace of the line containing the node's start row
---@param node TSNode
---@return string
function M.get_node_indent(node)
	local start_row = node:start()
	local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]
	if not line then
		return ""
	end
	return line:match("^(%s*)") or ""
end

return M
