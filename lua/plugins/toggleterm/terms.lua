local M = {}

local cached = require("my.tables").cached
local Terminal = require("toggleterm.terminal").Terminal

local opts = {
	zsh_r = {
		cmd = "zsh",
	},
	zsh_e = {
		cmd = "zsh",
	},
}

M.terms = cached(function(key)
	local o = opts[key] or {}
	o.display_name = o.display_name or key
	o.cmd = o.cmd or key
	return Terminal:new(o)
end)

return M
