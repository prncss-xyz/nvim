local M = {}

local function files_in(dir)
	local files = {}
	for name, kind in vim.fs.dir(dir) do
		if not vim.startswith(name, ".") and kind == "file" then
			files[vim.fs.joinpath(dir, name)] = true
		end
	end
	return files
end

function M.scan(root, statuses, default_status)
	local tasks = {}
	local status_names = {}
	for index, status in ipairs(statuses) do
		status_names[status.name] = index
	end
	assert(status_names[default_status], "Unknown default artifact task status: " .. tostring(default_status))

	local function visit(dir, parts)
		local entries = {}
		for name, kind in vim.fs.dir(dir) do
			if not vim.startswith(name, ".") then
				table.insert(entries, { name = name, kind = kind })
			end
		end
		table.sort(entries, function(a, b)
			return a.name < b.name
		end)

		local files = files_in(dir)
		local function add_task(task_file, task_parts, task_files, flat)
			local status = default_status
			for _, candidate in ipairs(statuses) do
				for _, filename in ipairs(candidate.files or {}) do
					if task_files[vim.fs.joinpath(dir, filename)] then
						status = candidate.name
					end
				end
			end
			local explicit = require("plugins.toggleterm.yaml").read_file(task_file).status
			if explicit ~= nil then
				if status_names[explicit] then
					status = explicit
				else
					status = default_status
					vim.notify(
						string.format(
							"Unknown artifact task status %q in %s; using %q",
							explicit,
							task_file,
							default_status
						),
						vim.log.levels.WARN
					)
				end
			end
			table.insert(tasks, {
				status = status,
				project = task_parts[1],
				branch = task_parts[#task_parts],
				parts = task_parts,
				cwd = dir,
				path = task_file,
				files = task_files,
				flat = flat,
			})
		end

		local task_file = vim.fs.joinpath(dir, "task.md")
		if files[task_file] then
			add_task(task_file, vim.deepcopy(parts), files, false)
		end
		for path in pairs(files) do
			local branch = vim.fs.basename(path):match("^(.*)%.task%.md$")
			if branch then
				local task_parts = vim.deepcopy(parts)
				table.insert(task_parts, branch)
				add_task(path, task_parts, { [path] = true }, true)
			end
		end

		for _, entry in ipairs(entries) do
			if entry.kind == "directory" then
				local child_parts = vim.deepcopy(parts)
				table.insert(child_parts, entry.name)
				visit(vim.fs.joinpath(dir, entry.name), child_parts)
			end
		end
	end

	visit(root, {})
	return tasks
end

function M.latest(tasks, predicate)
	local paths = {}
	for _, task in ipairs(tasks) do
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
