local M = {}

local Terminal = require("toggleterm.terminal").Terminal
local opts = {
	zsh_r = {
		cmd = "zsh",
	},
	zsh_e = {
		cmd = "zsh",
	},
}
local terms = {}
local mt = {}
function mt.__index(self, key)
	terms[key] = terms[key] or Terminal:new(opts[key] or { cmd = key })
	terms[key].display_name = terms[key].display_name or key
	terms[key].cmd = terms[key].cmd or key
	return terms[key]
end
M.terms = setmetatable({}, mt)

return M
