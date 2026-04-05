local M = {}

function M.current_file_ref()
	return "@" .. vim.fn.expand("%:.")
end

function M.current_line_ref()
	return M.current_file_ref() .. ":L" .. vim.fn.line(".")
end

function M.current_position_ref()
	return M.current_line_ref() .. ":C" .. vim.fn.col(".")
end

return M
