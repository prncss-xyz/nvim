local M = {}

function M.cachedFn(create)
	local cache = {}
	return function (key)
		cache[key] = cache[key] or create(key, function()
			cache[key] = nil
		end)
		return cache[key]
	end
end

return M
