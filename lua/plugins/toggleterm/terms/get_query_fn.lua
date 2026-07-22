local M = {}

M.any = {}

function M.get_query_fn(query)
	return function(item)
		for k, v in pairs(query) do
			if k == "prompt" or v == M.any then
			elseif type(v) == "table" and vim.islist(v) then
				if not vim.tbl_contains(v, item[k]) then
					return false
				end
			elseif item[k] ~= v then
				return false
			end
		end
		return true
	end
end

return M
