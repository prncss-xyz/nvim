local M = {}

function M.cachedFn(create)
	local cache = {}
	local function get(key)
		cache[key] = cache[key] or create(key)
		return cache[key]
	end
	local function remove(key)
		cache[key] = nil
	end
	return get, remove
end

return M
