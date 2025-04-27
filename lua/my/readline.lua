local M = {}

local function next_(pos, ofs)
	local row, col = unpack(pos)
	local buffers = require("flies.utils.buffers")
	local line = buffers.get_line(0, row)
	if col < line:len() + ofs then
		return { row, col + 1 }
	end
	if row == buffers.get_eob(0) then
		return { row, col }
	end
	row = row + 1
	line = buffers.get_line(0, row)
	if line == "" then
		return { row, 1 }
	end
	col = line:find("%S") or line:len()
	return { row, col }
end

local function prev(pos, ofs)
	local row, col = unpack(pos)
	local buffers = require("flies.utils.buffers")
	if row > buffers.get_eob(0) or buffers.get_line(0, row):sub(1, col - 1):match("^%s*$") then
		if row == 1 then
			return { 1, 1 }
		end
		row = row - 1
		local len = buffers.get_line(0, row):len()
		return { row, len + ofs }
	end
	return { row, col - 1 }
end

local function offset()
	if vim.fn.mode():sub(1, 1) == "i" then
		return 1
	end
	return 0
end

function M.fwd()
	local windows = require("flies.utils.windows")
	local pos = windows.get_cursor()
	windows.set_cursor(next_(pos, offset()))
end

function M.bwd()
	local windows = require("flies.utils.windows")
	local pos = windows.get_cursor()
	windows.set_cursor(prev(pos, offset()))
end

local function get_last(line)
	return string.find(line, ".%s*$") or 0
end

function M.eol()
	local windows = require("flies.utils.windows")
	local buffers = require("flies.utils.buffers")
	local eob = buffers.get_eob(0)
	local row, col = unpack(windows.get_cursor())
	local last = get_last(buffers.get_line(0, row))
	if (last == 0 or col >= last) and row < eob then
		row = row + 1
		last = get_last(buffers.get_line(0, row))
	end
	local off = last == 0 and 1 or offset()
	windows.set_cursor({ row, last + off })
end

return M
