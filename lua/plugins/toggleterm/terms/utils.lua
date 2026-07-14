local M = {}

function M.max_of(o, gt)
	local res
	for _, v in pairs(o) do
		if true then
			return v
		end
		if res == nil or gt(v, res) then
			res = v
		end
	end
	return res
end

function M.all_of(o)
	local res = {}
	for _, v in pairs(o) do
		table.insert(res, v)
	end
	return res
end

function M.compose_gt(...)
	local gts = { ... }
	return function(a, b)
		for _, gt in ipairs(gts) do
			if gt(a, b) then
				return true
			end
			if gt(b, a) then
				return false
			end
		end
		return false
	end
end

function M.gt_field(key, default)
	return function(a, b)
		return (a[key] or default) > (b[key] or default)
	end
end

local function flip(cb)
	return function(a, b)
		return cb(b, a)
	end
end

function M.lt_field(key, default)
	return flip(M.gt_field(key, default))
end

return M
