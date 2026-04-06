local M = {}

function M.cache2(cache, create)
	return function(p, q)
    cache[p] = cache[p] or {}
    cache[p][q] = cache[p][q] or create(p, q)
    return cache[p][q]
	end
end

return M
