local async = require("neoterm.helpers.term_templates")

local function executable(agent)
	local ok, config = pcall(require, "neoterm.agents." .. agent)
	return ok and config.executable or agent
end

return function(opts, callback)
	local agents = opts.agents or {}
	local aliases = opts.agent_aliases or {}
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
				})
				if agent ~= "agy" then
					table.insert(definitions, {
						index = index,
						name = agent .. ":resume",
						agent = agent,
						resume = true,
						tag = "agent",
					})
				end
				for alias, settings in pairs(aliases) do
					if settings[agent] then
						table.insert(definitions, {
							index = index,
							name = agent .. ":" .. alias,
							agent = agent,
							alias = alias,
							tag = "agent",
						})
					end
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
