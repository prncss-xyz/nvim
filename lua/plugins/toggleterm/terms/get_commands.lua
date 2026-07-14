local M = {}

local config = require("plugins.toggleterm.config")

local pkg_cache = {}

local function get_commands0(cwd)
	if not pkg_cache[cwd] then
		local commands = vim.tbl_extend("force", {}, config.commands)
		require("plugins.toggleterm.terms.package").add_npm_scripts(commands, cwd)
		pkg_cache[cwd] = commands
	end
	return pkg_cache[cwd]
end

local function get_hash(o)
	return string.format("%s:%s:%i", o.dir, o.key, o.instance_count)
end

function M.get_commands(filter)
	local commands = vim.deepcopy(get_commands0(vim.fn.getcwd()))
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
			v.dir = v.dir or vim.fn.getcwd()
			v.hash = get_hash(v)
			if filter(v) then
				res[k] = v
			end
		end
	end
	return res
end

return M
