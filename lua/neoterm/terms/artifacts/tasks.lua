local M = {}

local root
local tasks = {}
local files = {}
local projects
local watchers = {}
local listeners = {}
local refresh_timer
local started = false
local generation = 0
local rebuilding = false
local rebuild_again = false

local function stop_watchers()
	for _, watcher in ipairs(watchers) do
		watcher:stop()
		if not watcher:is_closing() then
			watcher:close()
		end
	end
	watchers = {}
end

local function frontmatter_text(text)
	return text:match("^%-%-%-%s*\n(.-)\n[%.-][%.-][%.-]%s*\n")
end

local function explicit_field(text, name)
	local frontmatter = frontmatter_text(text)
	if not frontmatter then
		return nil
	end
	local value = ("\n" .. frontmatter):match("\n" .. name .. ":[ \t]*([^\n#]+)")
	if not value then
		return nil
	end
	value = vim.trim(value)
	local quote = value:sub(1, 1)
	if (quote == '"' or quote == "'") and value:sub(-1) == quote then
		value = value:sub(2, -2)
	end
	return value
end

local function explicit_auto(text)
	local value = explicit_field(text, "auto")
	if not value then
		return nil
	end
	local step, variant = value:match("^([^:]+):(.+)$")
	return { step = vim.trim(step or value), variant = variant and vim.trim(variant) }
end

local function explicit_dependencies(text)
	local frontmatter = frontmatter_text(text)
	local result = {}
	if not frontmatter then
		return result
	end
	local value = frontmatter:match("\n?dependencies?:[ \t]*([^\n]*)")
	if not value then
		return result
	end
	local function add(item)
		item = vim.trim(item:gsub("%s+#.*$", ""))
		local quote = item:sub(1, 1)
		if (quote == '"' or quote == "'") and item:sub(-1) == quote then
			item = item:sub(2, -2)
		end
		if item ~= "" then
			table.insert(result, item)
		end
	end
	if value:match("^%s*%[") then
		for item in value:gmatch("[^%[%],]+") do
			add(item)
		end
	elseif vim.trim(value) ~= "" then
		add(value)
	else
		local tail = frontmatter:match("\n?dependencies?:[^\n]*\n(.*)") or ""
		for line in tail:gmatch("[^\n]+") do
			local item = line:match("^%s+%-%s+(.+)$") or line:match("^%-%s+(.+)$")
			if not item then
				break
			end
			add(item)
		end
	end
	return result
end

local function read_file(path, callback)
	vim.uv.fs_open(
		path,
		"r",
		438,
		vim.schedule_wrap(function(open_error, fd)
			if open_error or not fd then
				return callback("")
			end
			vim.uv.fs_fstat(
				fd,
				vim.schedule_wrap(function(stat_error, stat)
					if stat_error or not stat then
						vim.uv.fs_close(fd)
						return callback("")
					end
					vim.uv.fs_read(
						fd,
						stat.size,
						0,
						vim.schedule_wrap(function(read_error, data)
							vim.uv.fs_close(fd)
							callback(read_error and "" or data or "")
						end)
					)
				end)
			)
		end)
	)
end

local function notify_listeners()
	for listener in pairs(listeners) do
		pcall(listener)
	end
end

local request_rebuild

local function install_watchers(directories, project_directories)
	stop_watchers()
	local recursive = vim.fn.has("macunix") == 1 or vim.fn.has("win32") == 1
	local watched = {}
	for _, dir in ipairs(recursive and { root } or directories) do
		table.insert(watched, { path = dir, recursive = recursive })
	end
	for _, dir in ipairs(project_directories) do
		table.insert(watched, type(dir) == "table" and dir or { path = dir, recursive = false })
	end
	for _, dir in ipairs(watched) do
		local watcher = assert(vim.uv.new_fs_event())
		local ok = watcher:start(dir.path, { recursive = dir.recursive or false }, function(_, name)
			if refresh_timer and (not dir.file or not name or name == dir.file) then
				refresh_timer:stop()
				refresh_timer:start(100, 0, vim.schedule_wrap(request_rebuild))
			end
		end)
		if ok then
			table.insert(watchers, watcher)
		else
			watcher:close()
		end
	end
end

local function first_line(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local line = file:read("*l")
	file:close()
	return line
end

local function relative_to(directory, path)
	return vim.fs.abspath(path:sub(1, 1) == "/" and path or vim.fs.joinpath(directory, path))
end

local function git_directory(path)
	local directory = vim.fs.joinpath(path, ".git")
	local stat = vim.uv.fs_stat(directory)
	if not stat then
		return nil
	end
	if stat.type == "file" then
		local target = (first_line(directory) or ""):match("^gitdir: (.+)$")
		if not target then
			return nil
		end
		directory = relative_to(path, target)
	end
	local common = first_line(vim.fs.joinpath(directory, "commondir"))
	if common then
		directory = relative_to(directory, common)
	end
	return vim.uv.fs_realpath(directory) or vim.fs.normalize(directory)
end

local function finish_rebuild(id, directories, next_files, candidates)
	if id ~= generation then
		return
	end
	local branches = {}
	local checkouts = {}
	local project_directories = {}
	local config = require("neoterm.config")
	local project_root = config.dirs.projects
	if config.tasks.forked then
		assert(project_root, "Projects directory is not configured")
	end
	local function checkout(path, watch)
		if watch then
			table.insert(project_directories, { path = path, file = ".git" })
		end
		local git_dir = git_directory(path)
		if git_dir then
			table.insert(checkouts, { path = path, git_dir = git_dir })
		end
	end
	if project_root then
		local handle = vim.uv.fs_scandir(project_root)
		if handle then
			table.insert(project_directories, project_root)
			checkout(project_root)
			while true do
				local project, kind = vim.uv.fs_scandir_next(handle)
				if not project then
					break
				end
				if kind == "directory" then
					local directory = vim.fs.joinpath(project_root, project)
					table.insert(project_directories, directory)
					checkout(directory)
					branches[project] = {}
					for branch, branch_kind in vim.fs.dir(directory) do
						if branch_kind == "directory" then
							branches[project][branch] = true
							if branch ~= ".git" then
								checkout(vim.fs.joinpath(directory, branch), true)
							end
						end
					end
				end
			end
		end
	end
	table.sort(checkouts, function(left, right)
		return left.path < right.path
	end)
	local next_tasks = {}
	local pending = #candidates
	local function complete()
		pending = pending - 1
		if pending > 0 or id ~= generation then
			return
		end
		local flat_parts = {}
		local directory_parts = {}
		for _, task in ipairs(next_tasks) do
			local key = table.concat(task.parts, "/")
			if task.flat then
				flat_parts[key] = true
			else
				directory_parts[key] = true
			end
		end
		for _, task in ipairs(next_tasks) do
			local key = table.concat(task.parts, "/")
			if flat_parts[key] and directory_parts[key] then
				task.logical_status = "ERROR:DUPLICATE"
			end
		end
		local project_root = vim.fs.root(root, ".git") or root
		local by_path = {}
		for _, task in ipairs(next_tasks) do
			by_path[vim.fs.normalize(task.path)] = task
		end
		local function resolve(task, name)
			local path
			if name:match("^%./") and not vim.tbl_contains(vim.split(name, "/", { plain = true }), "..") then
				path = vim.fs.joinpath(task.cwd, name)
			elseif name:match("^~/") then
				path = vim.fs.joinpath(vim.uv.os_homedir(), name:sub(3))
			elseif name:match("^/") then
				path = name
			elseif not name:match("^%.") then
				path = vim.fs.joinpath(project_root, name)
			end
			local dependency = path and by_path[vim.fs.normalize(path)]
			return dependency and { dependency } or {}
		end
		for _, task in ipairs(next_tasks) do
			for _, name in ipairs(task.dependencies) do
				for _, dependency in ipairs(resolve(task, name)) do
					table.insert(dependency.dependents, table.concat(task.parts, "/"))
				end
			end
		end
		local config = require("neoterm.config").tasks
		local blocking = config.blocking
		local order = require("neoterm.terms.artifacts.statuses").order()
		local visited, stack, positions = {}, {}, {}
		local function visit(task)
			if positions[task] then
				for index = positions[task], #stack do
					stack[index].logical_status = "ERROR:CIRCULAR DEPENENCIES"
				end
				return
			end
			if visited[task] then
				return
			end
			positions[task] = #stack + 1
			table.insert(stack, task)
			local dependencies = {}
			for _, name in ipairs(task.dependencies) do
				for _, dependency in ipairs(resolve(task, name)) do
					visit(dependency)
					table.insert(dependencies, dependency)
				end
			end
			if not vim.startswith(task.logical_status, "ERROR:") then
				local status = task.status or config.default_status
				local blocked, indirect_error = false, false
				for _, dependency in ipairs(dependencies) do
					local dependency_status = dependency.logical_status
					if vim.startswith(dependency_status, "ERROR:") then
						indirect_error = true
					else
						if blocking and not vim.tbl_contains(blocking.unblock, dependency_status) then
							blocked = true
						end
					end
				end
				if indirect_error then
					task.logical_status = "ERROR:INDIRECT"
				elseif blocked and order[status] and order[status] < order[blocking.status] then
					task.logical_status = blocking.status
				else
					task.logical_status = status
				end
			end
			table.remove(stack)
			positions[task] = nil
			visited[task] = true
		end
		for _, task in ipairs(next_tasks) do
			visit(task)
		end
		tasks = next_tasks
		files = next_files
		projects = { branches = branches, checkouts = checkouts }
		install_watchers(directories, project_directories)
		rebuilding = false
		notify_listeners()
		if rebuild_again then
			rebuild_again = false
			request_rebuild()
		end
	end
	if pending == 0 then
		pending = 1
		complete()
		return
	end

	for _, candidate in ipairs(candidates) do
		read_file(candidate.path, function(text)
			if id ~= generation then
				return
			end
			local forked = false
			if branches[candidate.project] then
				local paths = require("neoterm.terms.artifacts.paths")
				local branch = paths.source(candidate.path).branch
				forked = not paths.is_default(branch) and branches[candidate.project][branch] == true
			end
			candidate.status = require("neoterm.terms.artifacts.statuses").resolve(
				explicit_field(text, "status") or require("neoterm.config").tasks.default_status,
				candidate.present,
				forked
			)
			candidate.logical_status = candidate.status
			candidate.auto = explicit_auto(text)
			candidate.dependencies = explicit_dependencies(text)
			candidate.dependents = {}
			table.insert(next_tasks, candidate)
			complete()
		end)
	end
end

local function rebuild()
	rebuilding = true
	generation = generation + 1
	local id = generation
	local directories = {}
	local next_files = {}
	local candidates = {}
	local pending = 1

	local function done()
		pending = pending - 1
		if pending == 0 then
			finish_rebuild(id, directories, next_files, candidates)
		end
	end

	local function visit(dir, parts)
		pending = pending + 1
		vim.uv.fs_scandir(
			dir,
			vim.schedule_wrap(function(err, handle)
				if id ~= generation then
					return
				end
				if err or not handle then
					done()
					return
				end
				table.insert(directories, dir)
				local directory_files = {}
				local child_dirs = {}
				while true do
					local name, kind = vim.uv.fs_scandir_next(handle)
					if not name then
						break
					end
					if not vim.startswith(name, ".") then
						local path = vim.fs.joinpath(dir, name)
						if kind == "file" then
							directory_files[path] = true
							next_files[path] = { executable = false }
							local file_path = path
							pending = pending + 1
							vim.uv.fs_stat(
								file_path,
								vim.schedule_wrap(function(stat_error, stat)
									if id == generation and not stat_error and stat then
										next_files[file_path].executable = bit.band(stat.mode, 73) ~= 0
									end
									done()
								end)
							)
						elseif kind == "directory" then
							table.insert(child_dirs, name)
						end
					end
				end

				local task_file = vim.fs.joinpath(dir, "task.md")
				local present = {}
				for path in pairs(directory_files) do
					present[vim.fs.basename(path)] = true
				end
				if directory_files[task_file] then
					table.insert(candidates, {
						project = parts[1],
						branch = parts[#parts],
						parts = vim.deepcopy(parts),
						cwd = dir,
						path = task_file,
						files = directory_files,
						present = present,
						flat = false,
					})
				end
				for path in pairs(directory_files) do
					local branch = vim.fs.basename(path):match("^(.*)%.task%.md$")
					if branch then
						local task_parts = vim.deepcopy(parts)
						table.insert(task_parts, branch)
						local flat_present = {}
						for name in pairs(present) do
							if vim.startswith(name, branch .. ".") then
								flat_present[name:sub(#branch + 2)] = true
							end
						end
						table.insert(candidates, {
							project = task_parts[1],
							branch = task_parts[#task_parts],
							parts = task_parts,
							cwd = dir,
							path = path,
							files = { [path] = true },
							present = flat_present,
							flat = true,
						})
					end
				end
				for _, name in ipairs(child_dirs) do
					local child_parts = vim.deepcopy(parts)
					table.insert(child_parts, name)
					visit(vim.fs.joinpath(dir, name), child_parts)
				end
				done()
			end)
		)
	end

	visit(root, {})
	done()
end

request_rebuild = function()
	if rebuilding then
		rebuild_again = true
		return
	end
	rebuild()
end

function M.start()
	if started then
		return
	end
	started = true
	root = assert(require("neoterm.config").dirs.artifacts, "Artifact directory is not configured")
	refresh_timer = assert(vim.uv.new_timer())
	request_rebuild()
end

function M.get()
	M.start()
	return tasks
end

function M.projects()
	M.start()
	return projects
end

function M.files(dir)
	M.start()
	local result = {}
	dir = vim.fs.normalize(dir)
	local prefix = dir .. "/"
	for path in pairs(files) do
		if path == dir or vim.startswith(path, prefix) then
			table.insert(result, path)
		end
	end
	table.sort(result)
	return result
end

function M.executables(dir)
	M.start()
	local result = {}
	dir = vim.fs.normalize(dir)
	local prefix = dir .. "/"
	for path, metadata in pairs(files) do
		if metadata.executable and (path == dir or vim.startswith(path, prefix)) then
			table.insert(result, path)
		end
	end
	table.sort(result)
	return result
end

---Logical status of the indexed task at `path`, or nil when it is not indexed.
---@param path string
---@return string|nil
function M.status(path)
	path = vim.fs.normalize(vim.fs.abspath(path))
	for _, task in ipairs(M.get()) do
		if task.path == path then
			return task.logical_status
		end
	end
end

local function precedes(left, right)
	for index = 1, math.min(#left, #right) do
		if left[index] ~= right[index] then
			return left[index] < right[index]
		end
	end
	return #left > #right
end

---Tasks with an `auto` field accepted by `predicate`, preferring the alphabetically first
---directory at every level, then the most deeply nested task.
---@param predicate? fun(task: table): boolean
---@return table[]
function M.auto_tasks(predicate)
	local result = vim.tbl_filter(function(task)
		return task.auto ~= nil and (predicate == nil or predicate(task))
	end, M.get())
	table.sort(result, function(left, right)
		return precedes(left.parts, right.parts)
	end)
	return result
end

--- Whether the task owning an artifact source runs its steps in a forked checkout.
--- Reads the `fork` frontmatter field of the owner task.md; defaults to true.
function M.fork(path)
	local task = require("neoterm.terms.artifacts.paths").source(path).task
	if not task or vim.fn.filereadable(task) == 0 then
		return true
	end
	local value = explicit_field(table.concat(vim.fn.readfile(task), "\n") .. "\n", "fork")
	if value == nil then
		return true
	end
	assert(value == "true" or value == "false", "Task fork must be true or false: " .. task)
	return value == "true"
end

function M.subscribe(listener)
	listeners[listener] = true
	return function()
		listeners[listener] = nil
	end
end

function M.latest(candidates, predicate)
	local paths = {}
	for _, task in ipairs(candidates) do
		if predicate(task) then
			for path in pairs(task.files) do
				paths[path] = true
			end
		end
	end
	local latest = require("neoterm.terms.artifacts.cwd").latest_file(paths)
	if latest then
		return latest
	end
	for path in pairs(paths) do
		local stat = assert(vim.uv.fs_stat(path), "Artifact file not found: " .. path)
		local modified = stat.mtime.sec * 1000000000 + stat.mtime.nsec
		if latest == nil or modified > latest.modified or (modified == latest.modified and path < latest.path) then
			latest = { path = path, modified = modified }
		end
	end
	return latest
end

return M
