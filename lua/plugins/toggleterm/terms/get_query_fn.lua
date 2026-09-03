local M = {}

M.any = function()
	return true
end

local function is_dir_match(dir, parent)
	if type(dir) ~= "string" or type(parent) ~= "string" then
		return false
	end
	local normalized_dir = vim.fs.normalize(dir)
	local normalized_parent = vim.fs.normalize(parent)
	if normalized_parent ~= "/" then
		normalized_parent = normalized_parent:gsub("/+$", "")
	end
	if type(vim.env.HOME) == "string" and normalized_parent == vim.fs.normalize(vim.env.HOME) then
		return normalized_dir == normalized_parent
	end
	return normalized_dir == normalized_parent
		or vim.startswith(normalized_dir, normalized_parent == "/" and "/" or normalized_parent .. "/")
end

local function matches_dir(query_dir, item_dir)
	if type(query_dir) == "table" and vim.islist(query_dir) then
		return vim.iter(query_dir):any(function(dir)
			return is_dir_match(item_dir, dir)
		end)
	end
	return is_dir_match(item_dir, query_dir)
end

function M.get_query_fn(query)
	return function(item)
		for k, v in pairs(query) do
			if k == "prompt" then
			elseif type(v) == "function" then
				if not v(item) then
					return false
				end
			elseif k == "dir" then
				if not matches_dir(v, item[k]) then
					return false
				end
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
