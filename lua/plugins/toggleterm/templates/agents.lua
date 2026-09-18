local async = require("plugins.toggleterm.templates.async")

return {
	generator = function(opts, callback)
		local agents = opts.agents or {}
		local pending = #agents
		local definitions = {}
		if pending == 0 then
			return vim.schedule(function()
				callback(definitions)
			end)
		end

		for index, agent in ipairs(agents) do
			async.executable(agent, function(installed)
				if installed then
					local priority = #agents - index + 1
					table.insert(definitions, {
						name = agent,
						priority = priority,
						builder = function()
							return {
								cmd = agent,
								priority = priority,
								auto_scroll = false,
								tag = "agent",
							}
						end,
					})
				end
				pending = pending - 1
				if pending == 0 then
					table.sort(definitions, function(a, b)
						return a.priority > b.priority
					end)
					callback(definitions)
				end
			end)
		end
	end,
}
