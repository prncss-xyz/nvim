return function(opts)
	if opts.tag ~= "agent" then
		return opts
	end
	local settings = require("neoterm.config").agent
	local agent = opts.agent or settings.default
	local config = require("neoterm.agents." .. agent)
	local alias = opts.alias and assert(settings.alias[opts.alias], "Unknown agent alias: " .. opts.alias)
	local resolved = vim.tbl_extend(
		"force",
		{ agent = agent, sandbox = require("my.conds").personal("bwrap") },
		alias and alias[agent] or {},
		opts
	)
	return vim.tbl_extend("force", {
		cmd = config.builder(resolved),
		auto_scroll = false,
		writable_dirs = config.writable_dirs,
		writable_files = config.writable_files,
		screen_manifest = config.screen_manifest,
	}, resolved)
end
