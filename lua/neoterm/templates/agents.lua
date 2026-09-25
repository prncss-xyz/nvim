local async = require("neoterm.helpers.term_templates")

local function executable(agent)
	local ok, config = pcall(require, "neoterm.agents." .. agent)
	return ok and config.executable or agent
end

return function(opts, callback)
		local agents = opts.agents or {}
		local pending = #agents
		local definitions = {}
		if pending == 0 then
			return callback(definitions)
		end

		for index, agent in ipairs(agents) do
			async.executable(executable(agent), function(installed)
				if installed then
					table.insert(definitions, {
						index = index,
						name = agent,
						agent = agent,
						tag = "agent",
						priority = agent == opts.default_agent and 100 or #agents - index + 1,
					})
				end
				pending = pending - 1
				if pending == 0 then
					table.sort(definitions, function(a, b)
						return a.index < b.index
					end)
					callback(definitions)
				end
			end)
		end
end
