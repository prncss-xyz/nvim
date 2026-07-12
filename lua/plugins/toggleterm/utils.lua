local M = {}

function M.first_of(commands)
	local res
	for _, v in pairs(commands) do
		if res and ((res.priority or 0) < (v.priority or 0)) or res == nil then
			res = v
		end
	end
	return res
end

function M.all_of(commands)
	local res = {}
	for _, v in pairs(commands) do
		table.insert(res, v)
	end
	return res
end

return M
