local M = {}

local root
local tasks = {}
local files = {}
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

local function explicit_status(text)
	local frontmatter = text:match("^%-%-%-%s*\n(.-)\n[%.-][%.-][%.-]%s*\n")
	if not frontmatter then
		return nil
	end
	local value = frontmatter:match("\n?status:%s*([^\n#]+)")
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

local function install_watchers(directories)
	stop_watchers()
	local recursive = vim.fn.has("macunix") == 1 or vim.fn.has("win32") == 1
	local watched = recursive and { root } or directories
	for _, dir in ipairs(watched) do
		local watcher = assert(vim.uv.new_fs_event())
		local ok = watcher:start(dir, { recursive = recursive }, function()
			if refresh_timer then
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

local function finish_rebuild(id, directories, next_files, candidates)
	if id ~= generation then
		return
	end
	local config = require("plugins.toggleterm.config")
	local status_names = {}
	for _, status in ipairs(config.status) do
		status_names[status.name] = true
	end
	assert(
		status_names[config.default_status],
		"Unknown default artifact task status: " .. tostring(config.default_status)
	)

	local next_tasks = {}
	local pending = #candidates
	local function complete()
		pending = pending - 1
		if pending > 0 or id ~= generation then
			return
		end
		tasks = next_tasks
		files = next_files
		install_watchers(directories)
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
			local status = config.default_status
			for _, configured in ipairs(config.status) do
				for _, filename in ipairs(configured.files or {}) do
					if candidate.files[vim.fs.joinpath(candidate.cwd, filename)] then
						status = configured.name
					end
				end
			end
			local explicit = explicit_status(text)
			if explicit ~= nil then
				if status_names[explicit] then
					status = explicit
				else
					vim.schedule(function()
						vim.notify(
							string.format(
								"Unknown artifact task status %q in %s; using %q",
								explicit,
								candidate.path,
								config.default_status
							),
							vim.log.levels.WARN
						)
					end)
				end
			end
			candidate.status = status
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
				if directory_files[task_file] then
					table.insert(candidates, {
						project = parts[1],
						branch = parts[#parts],
						parts = vim.deepcopy(parts),
						cwd = dir,
						path = task_file,
						files = directory_files,
						flat = false,
					})
				end
				for path in pairs(directory_files) do
					local branch = vim.fs.basename(path):match("^(.*)%.task%.md$")
					if branch then
						local task_parts = vim.deepcopy(parts)
						table.insert(task_parts, branch)
						table.insert(candidates, {
							project = task_parts[1],
							branch = task_parts[#task_parts],
							parts = task_parts,
							cwd = dir,
							path = path,
							files = { [path] = true },
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
	root = require("my.parameters").dirs.artifacts
	refresh_timer = assert(vim.uv.new_timer())
	request_rebuild()
end

function M.get()
	M.start()
	return tasks
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
	local latest = require("plugins.toggleterm.terms.artifact_cwd").latest_file(paths)
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
