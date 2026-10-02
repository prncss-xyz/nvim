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
		local name = agent.name
		async.executable(executable(name), function(installed)
			if installed then
				table.insert(definitions, {
					index = index,
					name = name,
					agent = name,
					tag = "agent",
				})
				if name ~= "agy" then
					table.insert(definitions, {
						index = index,
						name = name .. ":resume",
						agent = name,
						resume = true,
						tag = "agent",
					})
				end
				for alias in pairs(agent.alias or {}) do
					table.insert(definitions, {
						index = index,
						name = name .. ":" .. alias,
						agent = name,
						alias = alias,
						tag = "agent",
					})
				end
			end
			pending = pending - 1
			if pending == 0 then
				table.sort(definitions, function(a, b)
					if a.index ~= b.index then
						return a.index < b.index
					end
					return a.name < b.name
				end)
				callback(definitions)
			end
		end)
	end
end
