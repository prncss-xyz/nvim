local M = {}

local function is_agent(instance)
	return instance == nil or instance.tag == "agent"
end

local function path(ctx)
	if ctx.path:find("[^%w%._/%-]") then
		return string.format("%q", ctx.path)
	end

	return ctx.path
end

function M.path(ctx, instance)
	local value = path(ctx)
	if is_agent(instance) then
		return "@" .. value .. " "
	end

	return value
end

function M.row(ctx, instance)
	if is_agent(instance) then
		return M.path(ctx, instance) .. string.format(":L%i ", ctx.row)
	end

	return M.path(ctx, instance) .. string.format(":%i", ctx.row)
end

function M.position(ctx, instance)
	if is_agent(instance) then
		return M.path(ctx, instance) .. string.format(":L%iC:%i ", ctx.row, ctx.col)
	end

	return M.path(ctx, instance) .. string.format(":%i:%i", ctx.row, ctx.col)
end

return M
