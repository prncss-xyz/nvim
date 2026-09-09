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
	local value = path(ctx)
	if is_agent(instance) then
		return string.format("@%s:L%i ", value, ctx.row)
	end

	return string.format("%s:%i", value, ctx.row)
end

function M.position(ctx, instance)
	local value = path(ctx)
	if is_agent(instance) then
		return string.format("@%s:L%iC:%i ", value, ctx.row, ctx.col)
	end

	return string.format("%s:%i:%i", value, ctx.row, ctx.col)
end

return M
