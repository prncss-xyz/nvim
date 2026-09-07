local M = {}

local function agent_query(query)
	return query or { tag = "agent" }
end

function M.put_file_name(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), require("plugins.toggleterm.put.position").path)
end

function M.put_file_line(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), require("plugins.toggleterm.put.position").row)
end

function M.put_file_pos(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), require("plugins.toggleterm.put.position").position)
end

function M.put_hunk(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), require("plugins.toggleterm.put.hunk").hunk)
end

function M.put_diagnostics(scope, query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), function(ctx)
		return require("plugins.toggleterm.put.diagnostics").get_diagnostics(ctx, scope)
	end)
end

function M.put_selection(query)
	require("plugins.toggleterm.terms").send_str(agent_query(query), function(ctx)
		return require("plugins.toggleterm.put.selection").get_selection(ctx)
	end)
end


return M
