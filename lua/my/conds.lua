local M = {}

local function from_value(value)
	if type(value) == "function" then
		return value()
	end
	return value
end

local function cond(cb)
	return function(value, alt)
		return cb() and (from_value(value) or true) or (from_value(alt) or false)
	end
end

M.personal = cond(function()
	return vim.env.HOME == "/home/prncss"
end)

M.not_vscode = cond(function()
	return not vim.g.vscode
end)

return M
