local M = {}

local config = require("neoterm.config")
local templates = require("neoterm.term_templates")

function M.get_commands(filter, cwd, callback, prefer_direct)
	cwd = cwd or vim.fn.getcwd()
	local commands = vim.deepcopy(config.commands)
	local function matching(all_commands)
		local res = {}
		for k, v in pairs(all_commands) do
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
				v.cwd = v.cwd or cwd
				if filter(v) then
					res[k] = v
				end
			end
		end
		return res
	end
	if prefer_direct then
		local direct = matching(commands)
		if next(direct) then
			return callback(direct)
		end
	end
	templates.add_commands(commands, config.templates or {}, {
		agents = config.agents.list,
		cwd = cwd,
		file = vim.api.nvim_buf_get_name(0),
		filetype = vim.bo.filetype,
		steps = config.steps,
	}, function(all_commands)
		callback(matching(all_commands))
	end)
end

return M
