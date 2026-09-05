local M = {}

function M.path(ctx)
	if ctx.path:find("[^%w%._/%-]") then
		return string.format("@%q ", ctx.path)
	end

	return string.format("@%s ", ctx.path)
end

function M.row(ctx)
	return M.path(ctx) .. string.format(":L%i ", ctx.row)
end

function M.position(ctx)
	return M.path(ctx) .. string.format(":L%iC:%i ", ctx.row, ctx.col)
end

return M
