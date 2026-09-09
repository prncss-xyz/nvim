local last_value = ""

local function coordinates()
	local buffer = vim.api.nvim_get_current_buf()
	if vim.bo[buffer].buftype ~= "" or not vim.bo[buffer].buflisted then
		return last_value
	end

	local line = vim.fn.line(".")
	local column = vim.fn.col(".")
	local line_count = vim.fn.line("$")
	last_value = string.format(" %3d:%02d %d ", line, column, line_count)
	return last_value
end

return coordinates
