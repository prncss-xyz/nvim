local M = {}

local started = false
local fired = {}
local active = false
local watched = {}
local watching = false
local auto_listeners = {}

local function lock_path()
	return vim.fs.joinpath(vim.fn.stdpath("state"), "neoterm-auto.lock")
end

local function holder(path)
	local fd = vim.uv.fs_open(path, "r", 420)
	if not fd then
		return nil
	end
	local data = vim.uv.fs_read(fd, 32, 0)
	vim.uv.fs_close(fd)
	return tonumber(data) or 0
end

local function alive(pid)
	local ok, err = vim.uv.kill(pid, 0)
	return ok ~= nil or not tostring(err):find("ESRCH", 1, true)
end

local function acquire()
	local path = lock_path()
	local pid = vim.uv.os_getpid()
	local current = holder(path)
	if current == pid then
		return true
	end
	if current and current > 0 and alive(current) then
		return false
	end
	if current then
		vim.uv.fs_unlink(path)
	end
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	local temporary = path .. "." .. pid
	assert(vim.fn.writefile({ tostring(pid) }, temporary) == 0, "Could not write auto lock: " .. temporary)
	vim.uv.fs_link(temporary, path)
	vim.uv.fs_unlink(temporary)
	return holder(path) == pid
end

function M.release()
	local path = lock_path()
	if holder(path) == vim.uv.os_getpid() then
		vim.uv.fs_unlink(path)
	end
end

local function list(value)
	if value == nil then
		return {}
	end
	return type(value) == "table" and value or { value }
end

local function unconditional(step)
	return #step.auto == 0 and #list(step.source) == 0
end

local function auto_steps()
	local result = {}
	for _, step in ipairs(require("neoterm.config").steps or {}) do
		if step.auto ~= nil and not unconditional(step) then
			table.insert(result, step)
		end
	end
	return result
end

local function ready_source(step, task)
	for _, name in ipairs(step.auto) do
		if not task.present[name] then
			return nil
		end
	end
	for _, name in ipairs(list(step.target)) do
		if task.present[name] then
			return nil
		end
	end
	local sources = list(step.source)
	if #sources == 0 then
		return task.path
	end
	for _, name in ipairs(sources) do
		if task.present[name] then
			return vim.fs.joinpath(task.cwd, name)
		end
	end
end

local function trigger(step, task, source)
	local checkouts = require("neoterm.terms.artifacts.paths").checkouts(source)
	if #checkouts ~= 1 then
		vim.notify(
			string.format(
				"Auto step %s skipped for %s: expected one checkout, found %d%s",
				step.name,
				task.cwd,
				#checkouts,
				#checkouts > 0 and " (" .. table.concat(checkouts, ", ") .. ")" or ""
			),
			vim.log.levels.WARN
		)
		return
	end
	local cwd = checkouts[1]
	local commands = require("neoterm.terms.artifacts.commands")
	for _, definition in ipairs(commands.for_file({ cwd = cwd, file = source, steps = { step }, executables = false })) do
		definition.confirm = false
		commands.run(definition)
	end
end

function M.check(tasks)
	local steps = auto_steps()
	local leading = #steps > 0 and acquire()
	local next_fired = {}
	for _, task in ipairs(tasks) do
		if not task.flat then
			for _, step in ipairs(steps) do
				local source = ready_source(step, task)
				if source then
					local key = task.path .. "\0" .. step.name
					next_fired[key] = true
					if leading and not fired[key] then
						local ok, err = pcall(trigger, step, task, source)
						if not ok then
							vim.notify(
								string.format("Auto step %s failed for %s: %s", step.name, task.cwd, err),
								vim.log.levels.ERROR
							)
						end
					end
				end
			end
		end
	end
	fired = next_fired
end

function M.start()
	if started then
		return
	end
	started = true
	for _, step in ipairs(require("neoterm.config").steps or {}) do
		if step.auto ~= nil and unconditional(step) then
			vim.notify(
				string.format("Step %s has an empty auto and no source; it will not auto-trigger", step.name),
				vim.log.levels.WARN
			)
		end
	end
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("neoterm-auto-lock", { clear = true }),
		callback = M.release,
	})
	local tasks = require("neoterm.terms.artifacts.tasks")
	tasks.subscribe(function()
		M.check(tasks.get())
	end)
	tasks.start()
end

local function auto_step(task)
	return vim.iter(require("neoterm.config").steps or {}):find(function(step)
		return step.name == task.auto.step
	end)
end

local function auto_variant(task, step)
	return task.auto.variant or (step.variants or {})[1]
end

local function auto_file(task, step)
	for _, name in ipairs(list(step.source)) do
		if task.present[name] then
			return vim.fs.joinpath(task.cwd, task.flat and task.branch .. "." .. name or name)
		end
	end
	return task.path
end

local function default_checkout(task)
	local config = require("neoterm.config")
	return require("neoterm.terms.artifacts.paths").checkout(task.project, config.default_branches[1])
end

local function settled(task)
	local blocking = require("neoterm.config").tasks.blocking
	return blocking ~= nil
		and (task.logical_status == blocking.status or vim.tbl_contains(blocking.unblock, task.logical_status))
end

local function auto_enabled(task)
	local step = auto_step(task)
	if step == nil or settled(task) then
		return false
	end
	return require("neoterm.terms.artifacts.commands").is_enabled({
		cwd = default_checkout(task),
		file = auto_file(task, step),
		step = step,
		variant = auto_variant(task, step),
	})
end

---Auto steps `trigger_next` would run, in execution order. `checkouts` lists every checkout
---matching `file`; `cwd` is the one the step runs in, nil when that is ambiguous.
---@return { task: table, step: table, variant?: string, file: string, checkouts: string[], cwd?: string }[]
function M.upcoming()
	local resolve = require("neoterm.terms.artifacts.paths").checkout_resolver()
	return vim.tbl_map(function(task)
		local step = assert(auto_step(task))
		local file = auto_file(task, step)
		local checkouts = resolve(file)
		return {
			task = task,
			step = step,
			variant = auto_variant(task, step),
			file = file,
			checkouts = checkouts,
			cwd = #checkouts <= 1 and (checkouts[1] or default_checkout(task)) or nil,
		}
	end, require("neoterm.terms.artifacts.tasks").auto_tasks(auto_enabled))
end

function M.trigger_next(predicate)
	local item = vim.iter(M.upcoming()):find(function(candidate)
		return predicate == nil or predicate(candidate.task)
	end)
	if not item then
		if predicate == nil then
			vim.notify("No auto task")
		end
		return
	end
	assert(
		item.cwd,
		"Expected at most one checkout for " .. item.file .. ", found " .. table.concat(item.checkouts, ", ")
	)
	local step = vim.deepcopy(item.step)
	step.variants = item.variant and { item.variant } or nil
	local commands = require("neoterm.terms.artifacts.commands")
	local definitions = commands.for_file({ cwd = item.cwd, file = item.file, steps = { step }, executables = false })
	assert(#definitions == 1, "Expected one definition for " .. step.name .. " on " .. item.file)
	commands.run(definitions[1])
	return item.task
end

local function notify_auto()
	for listener in pairs(auto_listeners) do
		listener()
	end
end

local function advance(force)
	if not active then
		return
	end
	local limit = require("neoterm.config").max_parallel_flows
	assert(type(limit) == "number" and limit >= 1 and limit % 1 == 0, "max_parallel_flows must be a positive integer")
	local occupied = {}
	local remaining = {}
	for _, task in ipairs(watched) do
		local status = require("neoterm.terms.artifacts.tasks").status(task.path)
		if status == nil then
			vim.notify("Watched task " .. table.concat(task.parts, "/") .. " disappeared", vim.log.levels.WARN)
		elseif not vim.tbl_contains(require("neoterm.config").tasks.blocking.unblock, status) then
			table.insert(remaining, task)
			occupied[task.project] = true
		end
	end
	local changed = #remaining ~= #watched
	watched = remaining
	while #watched < limit do
		local ok, result = pcall(M.trigger_next, function(task)
			return not occupied[task.project]
		end)
		if not ok then
			vim.notify("Auto mode stopped: " .. tostring(result), vim.log.levels.ERROR)
			active = false
			break
		end
		if result == nil then
			break
		end
		changed = true
		table.insert(watched, result)
		occupied[result.project] = true
	end
	active = active and #watched > 0
	if changed or not active or force then
		notify_auto()
	end
end

function M.auto_trigger_next()
	active = not active
	if not watching then
		watching = true
		require("neoterm.terms.artifacts.tasks").subscribe(advance)
	end
	if active then
		advance(true)
	else
		notify_auto()
	end
end

function M.auto_status()
	if active then
		local names = vim.tbl_map(function(task)
			return table.concat(task.parts, "/")
		end, watched)
		return "waiting for task " .. table.concat(names, ", ")
	end
end

function M.watched_parts()
	if active then
		return vim.tbl_map(function(task)
			return task.parts
		end, watched)
	end
end

---@param listener fun()
---@return fun() unsubscribe
function M.subscribe_auto(listener)
	auto_listeners[listener] = true
	return function()
		auto_listeners[listener] = nil
	end
end

return M
