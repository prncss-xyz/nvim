local M = {}

local function hunk_range(hunk, line_count)
	local start = hunk.added.start
	if hunk.added.count == 0 then
		local line = math.max(1, math.min(start, line_count))
		return line, line
	end
	return start, start + hunk.added.count - 1
end

local function format_hunk(ctx, hunk, line)
	local lines = { string.format("@%s :L%i %s", ctx.path, line, hunk.head) }
	vim.list_extend(lines, hunk.lines)
	return table.concat(lines, "\n") .. "\n"
end

function M.hunk(ctx)
	local hunks = require("gitsigns").get_hunks(ctx.bufnr) or {}
	if #hunks == 0 then
		vim.notify("No current or next hunk", vim.log.levels.WARN)
		return
	end

	table.sort(hunks, function(left, right)
		return left.added.start < right.added.start
	end)

	local line_count = vim.api.nvim_buf_line_count(ctx.bufnr)
	local next_hunk

	for _, hunk in ipairs(hunks) do
		local start, finish = hunk_range(hunk, line_count)
		if ctx.row >= start and ctx.row <= finish then
			return format_hunk(ctx, hunk, start)
		end
		if not next_hunk and start > ctx.row then
			next_hunk = { hunk = hunk, line = start }
		end
	end

	if next_hunk then
		return format_hunk(ctx, next_hunk.hunk, next_hunk.line)
	end
end

return M
