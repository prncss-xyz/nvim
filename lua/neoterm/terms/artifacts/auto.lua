local M = {}

local started = false
local fired = {}

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

local function auto_enabled(task)
	local step = auto_step(task)
	if step == nil then
		return false
	end
	return require("neoterm.terms.artifacts.commands").is_enabled({
		cwd = default_checkout(task),
		file = auto_file(task, step),
		step = step,
		variant = auto_variant(task, step),
	})
end

function M.trigger_next()
	local task = require("neoterm.terms.artifacts.tasks").next_auto(auto_enabled)
	if not task then
		vim.notify("No auto task")
		return
	end
	local step = vim.deepcopy(assert(auto_step(task)))
	local variant = auto_variant(task, step)
	step.variants = variant and { variant } or nil
	local file = auto_file(task, step)
	local checkouts = require("neoterm.terms.artifacts.paths").checkouts(file)
	assert(#checkouts <= 1, "Expected at most one checkout for " .. file .. ", found " .. table.concat(checkouts, ", "))
	local commands = require("neoterm.terms.artifacts.commands")
	local definitions = commands.for_file({
		cwd = checkouts[1] or default_checkout(task),
		file = file,
		steps = { step },
		executables = false,
	})
	assert(#definitions == 1, "Expected one definition for " .. step.name .. " on " .. file)
	commands.run(definitions[1])
end

return M
