local M = {}

M.any = {}

function M.get_query_fn(query)
	return function(item)
		for k, v in pairs(query) do
			if k == "prompt" then
			elseif v == M.any then
			elseif type(v) == "table" and vim.islist(v) and not vim.tbl_contains(v, item[k]) then
				return false
			elseif item[k] ~= v then
				return false
			end
		end
		return true
	end
end

return M
