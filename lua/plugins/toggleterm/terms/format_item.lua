local M = {}

local default_icon = "● "

local status_icons = {
	alive = "○ ",
	exited = "✗ ",
}

local function pad(s, len)
	if #s >= len then
		return s
	end
	return s .. string.rep(" ", len - #s)
end

function M.format_item(item)
	local res = status_icons[item.status] or default_icon
	res = res .. pad(item.key, 20)
	if item.display_name == item.key then
		return res
	end
	return res .. "  \u{2014}  " .. item.display_name
end

return M
