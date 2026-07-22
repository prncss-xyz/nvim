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

local function format_dir(dir)
	local home = vim.env.HOME
	if dir == home then
		return "~"
	end
	if dir and home and dir:sub(1, #home + 1) == home .. "/" then
		return "~/" .. dir:sub(#home + 2)
	end
	return dir or ""
end

function M.format_item(global)
	return function(item)
		local res = status_icons[item.status] or default_icon
		res = res .. pad(item.key .. ":" .. item.instance_count, 20)
		if item.display_name ~= item.key then
			res = res .. "  \u{2014}  " .. item.display_name
		end
		if global then
			res = res .. " (" .. format_dir(item.dir) .. ")"
		end
		return res
	end
end

return M
