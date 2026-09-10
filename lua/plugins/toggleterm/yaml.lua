local config = require("plugins.toggleterm.config").yaml

local M = {}

local function frontmatter(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if lines[1] ~= "---" then
		return nil
	end

	for index = 2, #lines do
		if lines[index] == "---" or lines[index] == "..." then
			return {
				last_line = index,
				text = table.concat(vim.list_slice(lines, 2, index - 1), "\n"),
			}
		end
	end

	error("unterminated YAML frontmatter")
end

function M.read(bufnr)
	local result = frontmatter(bufnr or 0)
	if not result then
		return {}
	end

	return config.decode(result.text)
end

function M.write(bufnr, value)
	assert(type(value) == "table", "Markdown frontmatter must be a YAML mapping")
	bufnr = bufnr or 0
	local current = frontmatter(bufnr)
	local replacement = { "---" }
	vim.list_extend(replacement, vim.split(config.encode(value), "\n", { plain = true, trimempty = true }))
	table.insert(replacement, "---")

	if current then
		vim.api.nvim_buf_set_lines(bufnr, 0, current.last_line, false, replacement)
	else
		table.insert(replacement, "")
		vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, replacement)
	end
end

return M
