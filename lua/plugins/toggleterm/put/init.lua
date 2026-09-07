local M = {}

function M.put_file_name()
	require("plugins.toggleterm.terms").send_str({ key = "artifact" }, require("plugins.toggleterm.put.position").path)
end

function M.put_file_line()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, require("plugins.toggleterm.put.position").row)
end

function M.put_file_pos()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, require("plugins.toggleterm.put.position").position)
end

function M.put_hunk()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, require("plugins.toggleterm.put.hunk").hunk)
end

function M.put_diagnostics(scope)
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return require("plugins.toggleterm.put.diagnostics").get_diagnostics(ctx, scope)
	end)
end

function M.put_selection()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return require("plugins.toggleterm.put.selection").get_selection(ctx)
	end)
end


return M
