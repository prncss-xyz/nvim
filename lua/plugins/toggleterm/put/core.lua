local M = {}

local function agent_query(query)
	return query or { tag = "agent" }
end

function M.path(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), require("plugins.toggleterm.put.position").path)
end

function M.line(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), require("plugins.toggleterm.put.position").row)
end

function M.position(query)
	require("plugins.toggleterm.terms").send_str(
		agent_query(query),
		require("plugins.toggleterm.put.position").position
	)
end

function M.hunk(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), require("plugins.toggleterm.put.hunk").hunk)
end

function M.diagnostics(scope, query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), function(ctx)
		return require("plugins.toggleterm.put.diagnostics").get_diagnostics(ctx, scope)
	end)
end

function M.selection(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), function(ctx)
		return require("plugins.toggleterm.put.selection").get_selection(ctx)
	end)
end

local vars = {
	path = require("plugins.toggleterm.put.position").path,
	line = require("plugins.toggleterm.put.position").row,
	position = require("plugins.toggleterm.put.position").position,
	hunk = require("plugins.toggleterm.put.hunk").hunk,
	selection = require("plugins.toggleterm.put.selection").get_selection,
}

function M.template(str)
	return function(query)
		return (string.gsub(str, "%b{}", function(match)
			local key = match:sub(2, -2)
			return assert(vars[key], "unknown template variable: " .. key)(query)
		end))
	end
end

return M
