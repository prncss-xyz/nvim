local M = {}

local vars = {
	selection = function(ctx)
		return ctx.selection or require("plugins.toggleterm.put.selection").get_selection(ctx)
	end,
	path = require("plugins.toggleterm.put.position").path,
	line = require("plugins.toggleterm.put.position").row,
	position = require("plugins.toggleterm.put.position").position,
	hunk = require("plugins.toggleterm.put.hunk").hunk,
	project_diagnostic = require("plugins.toggleterm.put.diagnostics").get_diagnostics("project"),
	file_diagnostic = require("plugins.toggleterm.put.diagnostics").get_diagnostics("file"),
	next_diagnostic = require("plugins.toggleterm.put.diagnostics").get_diagnostics("next"),
}

function M.capture(str)
	local invocation = {}
	if str:find("{selection}", 1, true) then
		invocation.selection = require("plugins.toggleterm.put.selection").capture()
	end
	return invocation
end

function M.template(str)
	return function(query, instance)
		return (
			string.gsub(str, "%b{}", function(match)
				local key = match:sub(2, -2)
				return assert(vars[key], "unknown template variable: " .. key)(query, instance)
			end)
		)
	end
end

return M
