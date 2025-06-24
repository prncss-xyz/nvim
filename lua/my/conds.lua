local M = {}

local function negate(cb)
	return function()
		return not cb()
	end
end

local function always(value)
	return function()
		return value
	end
end

local function personal()
	if vim.env.HOME == "/home/prncss" then
		return true
	end
end

local function vscode()
	return vim.g.vscode
end

local function from_value(value, default)
	if value == nil then
		return default
	end
	if type(value) == "function" then
		return value()
	end
	return value
end

local function cond(cb)
	return function(value, alt)
		if cb() then
			return from_value(value, true)
		end
		return from_value(alt)
	end
end

M.personal = cond(personal)

M.work = cond(negate(personal))

-- never enable for work
-- local avante = always(false)
local avante = personal
M.avante = cond(avante)
-- M.copilot = M.work
M.copilot = cond(negate(avante))

M.not_vscode = cond(negate(vscode))

M.tui = cond(function()
	return not (vim.g.vscode or vim.g.neovide)
end)

return M
