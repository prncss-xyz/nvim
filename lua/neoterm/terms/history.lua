local M = {}

function M.create_history(key)
	local history = {}
	local function find(cb)
		for i = #history, 1, -1 do
			local v = history[i]
			if cb(v) then
				return v
			end
		end
	end

	local function filter(cb)
		local res = {}
		for i = #history, 1, -1 do
			local v = history[i]
			if cb(v) then
				table.insert(res, v)
			end
		end
		return res
	end

	-- removes a potential previous occurrence of an item
	-- with a matching key field and inserts the new item at
	-- the end of the list
	local function insert(item)
		local id = item[key]
		local write_index = 1
		for _, existing_item in ipairs(history) do
			if existing_item[key] ~= id then
				history[write_index] = existing_item
				write_index = write_index + 1
			end
		end
		history[write_index] = item
	end

	--- removes an item with a matching key field
	local function purge(id)
		local write_index = 1
		for _, existing_item in ipairs(history) do
			if existing_item[key] ~= id then
				history[write_index] = existing_item
				write_index = write_index + 1
			end
		end
		history[write_index] = nil
	end

	return {
		find = find,
		filter = filter,
		insert = insert,
		purge = purge,
		dump = function()
			dd(history)
		end,
	}
end

return M
