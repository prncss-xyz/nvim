local M = {}

function M.agent(opts)
	if opts.tag ~= "agent" then
		return opts
	end
	local agent = opts.agent or require("neoterm.config").agent.default
	local config = require("neoterm.agents." .. agent)
	local resolved = vim.tbl_extend("force", { agent = agent, sandbox = require("my.conds").personal("bwrap") }, opts)
	return vim.tbl_extend("force", {
		cmd = config.builder(resolved),
		auto_scroll = false,
		writable_dirs = config.writable_dirs,
		writable_files = config.writable_files,
		screen_manifest = config.screen_manifest,
	}, resolved)
end

return M
