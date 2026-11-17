local M = {}

local tasks = {}
local projects = {}
local listeners = {}

local function notify()
	for listener in pairs(listeners) do
		listener()
	end
end

---@param path string task file the terminal's step belongs to
---@param project string
---@param owner table terminal item; a task stays active while any owner remains
function M.add(path, project, owner)
	local entry = tasks[path]
	if entry == nil then
		entry = { project = project, owners = {} }
		tasks[path] = entry
		projects[project] = (projects[project] or 0) + 1
	end
	local fresh = next(entry.owners) == nil
	entry.owners[owner] = true
	if fresh then
		notify()
	end
end

---@param path string
---@param owner table
function M.remove(path, owner)
	local entry = tasks[path]
	if entry == nil or not entry.owners[owner] then
		return
	end
	entry.owners[owner] = nil
	if next(entry.owners) == nil then
		tasks[path] = nil
		projects[entry.project] = projects[entry.project] > 1 and projects[entry.project] - 1 or nil
		notify()
	end
end

---@param path string
---@return boolean
function M.has(path)
	return tasks[path] ~= nil
end

---Projects with at least one active task, mapped to how many; do not mutate.
---@return table<string, integer>
function M.projects()
	return projects
end

---@param listener fun()
---@return fun() unsubscribe
function M.subscribe(listener)
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

return M
