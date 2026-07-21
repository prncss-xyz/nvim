local M = {}

M.any = {}

function M.get_query_fn(query)
	query = query or {}
	return function(item)
		for k, v in pairs(query) do
			if k == "prompt" then
			elseif k == "count" then
				local count = vim.v.count
				if count > 0 and query.instance_count ~= count then
					return false
				end
			elseif v == M.any then
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
