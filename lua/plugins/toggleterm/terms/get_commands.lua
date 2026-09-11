local M = {}

local config = require("plugins.toggleterm.config")
local templates = require("plugins.toggleterm.templates")

function M.get_commands(filter, cwd)
	cwd = cwd or vim.fn.getcwd()
	local commands = vim.deepcopy(config.commands)
	templates.add_commands(commands, config.templates or {}, {
		dir = cwd,
		filetype = vim.bo.filetype,
		tagger = config.packages and config.packages.tagger,
	})
	local res = {}
	for k, v in pairs(commands) do
		if type(v) == "table" then
			v = vim.tbl_extend("force", {}, v)
		elseif type(v) == "function" then
			v = v()
		end
		if type(v) == "string" then
			v = { cmd = v }
		end
		if v then
			v.key = k
			v.display_name = v.display_name or k
			v.tag = v.tag or k
			v.idle_timeout = v.idle_timeout or config.idle_timeout
			v.instance_count = vim.v.count1
			v.dir = v.dir or cwd
			if filter(v) then
				res[k] = v
			end
		end
	end
	return res
end

return M
