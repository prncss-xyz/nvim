local M = {}

function M.reader(bufnr)
	local function last_row()
		local row = vim.api.nvim_buf_line_count(bufnr)
		while row > 0 do
			if vim.api.nvim_buf_get_lines(bufnr, row - 1, row, true)[1] ~= "" then
				break
			end
			row = row - 1
		end
		return row
	end

	return {
		lines = function(count)
			assert(
				type(count) == "number" and count >= 0 and count % 1 == 0,
				"Line count must be a nonnegative integer"
			)
			local row = last_row()
			return vim.api.nvim_buf_get_lines(bufnr, math.max(0, row - count), row, true)
		end,
		last_line = function()
			local row = last_row()
			if row == 0 then
				return nil
			end
			return vim.api.nvim_buf_get_lines(bufnr, row - 1, row, true)[1]
		end,
	}
end

return M
