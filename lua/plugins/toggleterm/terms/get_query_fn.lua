local M = {}

local function transform_dir(dir)
	if dir == "" then
		return nil
	end
	if dir == nil then
		return {
			vim.env.HOME,
			vim.fn.getcwd(),
		}
	end
	return dir
end

function M.get_query_fn(o)
	local query = vim.deepcopy(o or {})
	query.prompt = nil
	query.dir = transform_dir(query.dir)
	local count = vim.v.count
	if count > 0 then
		query.instance_count = count
	end
	return function(item)
		for k, v in pairs(query) do
			if type(v) == "table" and vim.islist(v) then
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
