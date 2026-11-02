local M = {}

local function config()
	return require("neoterm.config").tasks
end

local function enabled(entry)
	return entry.enabled ~= false
end

---Enabled status entries, in configuration order.
---@return table[]
function M.list()
	local result = vim.tbl_filter(enabled, config().status)
	for _, entry in ipairs(result) do
		assert(entry.name ~= "all", "'all' is a reserved mode: disable it in tasks.modes")
	end
	return result
end

---Enabled status names, in configuration order.
---@return string[]
function M.names()
	return vim.tbl_map(function(entry)
		return entry.name
	end, M.list())
end

---Position of each enabled status in configuration order.
---@return table<string, integer>
function M.order()
	local result = {}
	for index, name in ipairs(M.names()) do
		result[name] = index
	end
	return result
end

---Statuses of each mode. `all` holds every enabled status unless disabled in `tasks.modes`.
---@return table<string, string[]>
function M.modes()
	local result = { all = M.names() }
	for _, entry in ipairs(M.list()) do
		for _, mode in ipairs(entry.modes or {}) do
			result[mode] = result[mode] or {}
			table.insert(result[mode], entry.name)
		end
	end
	for _, mode in ipairs(config().modes or {}) do
		if not enabled(mode) then
			result[mode.name] = nil
		end
	end
	return result
end

---Resolves a task's status: the latest listed status among the given one and those
---whose `files` exist. Unknown statuses are returned as is, to be reported.
---@param status string
---@param present table<string, boolean> file names in the task, without the prefix of flat tasks
---@return string
function M.resolve(status, present)
	local statuses = M.list()
	local position = M.order()[status]
	if not position then
		return status
	end
	for index = #statuses, position + 1, -1 do
		for _, file in ipairs(statuses[index].files or {}) do
			if present[file] then
				return statuses[index].name
			end
		end
	end
	return status
end

return M
