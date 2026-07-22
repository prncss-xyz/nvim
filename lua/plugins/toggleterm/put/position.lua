local M = {}

function M.path(ctx)
	return string.format("@%s ", ctx.path)
end

function M.row(ctx)
	return string.format("@%s :L%i ", ctx.path, ctx.row)
end

function M.position(ctx)
	return string.format("@%s :L%iC:%i ", ctx.path, ctx.row, ctx.col)
end

return M
