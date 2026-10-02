return function(opts)
	if opts.tag ~= "agent" then
		return opts
	end
	local settings = require("neoterm.config").agents
	local name = opts.agent or settings[1].name
	local agent
	for _, entry in ipairs(settings) do
		if entry.name == name then
			agent = entry
			break
		end
	end
	assert(agent, "Unknown agent: " .. name)
	local config = require("neoterm.agents." .. name)
	local alias = opts.alias and assert(agent.alias and agent.alias[opts.alias], "Unknown agent alias: " .. opts.alias)
	local resolved = vim.tbl_extend(
		"force",
		{ agent = name },
		agent.command or {},
		alias or {},
		opts
	)
	if resolved.resume then
		assert(
			resolved.title == nil or type(resolved.title) == "string" and resolved.title ~= "",
			"Invalid agent title"
		)
		resolved.provider = nil
		resolved.model = nil
		resolved.effort = nil
	end
	return vim.tbl_extend("force", {
		cmd = config.builder(resolved),
		auto_scroll = false,
		writable_dirs = config.writable_dirs,
		writable_files = config.writable_files,
		screen_manifest = config.screen_manifest,
	}, resolved)
end
