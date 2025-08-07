local M = {}

function M.deep_merge(t1, t2)
	local offset = #t1
	for k, v in pairs(t2) do
		if (type(v) == "table") and (type(t1[k] or false) == "table") then
			M.deep_merge(t1[k], t2[k])
		elseif type(k) == "number" then
			t1[offset + k] = v
		else
			t1[k] = v
		end
	end
	return t1
end

function M.cached(create)
	local cache = {}
	local mt = {}
	function mt:__index(key)
		cache[key] = cache[key] or create(key)
		return cache[key]
	end
	return setmetatable({}, mt)
end

return M
