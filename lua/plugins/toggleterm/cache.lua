local M = {}

function M.create_cache(n)
	local cache = {}

	local function get(...)
		local value = cache
		for _, key in ipairs({ ... }) do
			if value == nil then
				break
			end
			value = value[key]
		end
		return value
	end

	local function set(...)
		local args = { ... }
		local value = cache
		for index, key in ipairs(args) do
			if index + 1 == #args then
				value[key] = args[index + 1]
				break
			end
			if value[key] == nil then
				value[key] = {}
			end
			value = value[key]
		end
	end

	local function append(items, item)
		local result = vim.list_extend({}, items)
		result[#result + 1] = item
		return result
	end

	local function visit(callback, value, depth, path)
		for key, child in pairs(value) do
			local next_path = append(path, key)
			if depth == 1 then
				callback(append(next_path, child))
			else
				visit(callback, child, depth - 1, next_path)
			end
		end
	end

	return {
		get = get,
		set = set,
		each = function(callback)
			visit(callback, cache, n, {})
		end,
	}
end

return M
