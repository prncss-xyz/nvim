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

function M.scan(root, statuses)
	local tasks = {}
	local status_names = {}
	for index, status in ipairs(statuses) do
		status_names[status.name] = index
	end

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
		local task_file = vim.fs.joinpath(dir, "task.md")
		if files[task_file] then
			local status = statuses[1].name
			for _, candidate in ipairs(statuses) do
				for _, filename in ipairs(candidate.files or {}) do
					if files[vim.fs.joinpath(dir, filename)] then
						status = candidate.name
					end
				end
			end
			local explicit = require("plugins.toggleterm.yaml").read_file(task_file).status
			if explicit ~= nil then
				assert(status_names[explicit], "Unknown artifact task status: " .. tostring(explicit))
				status = explicit
			end
			table.insert(tasks, {
				status = status,
				project = parts[1],
				branch = parts[#parts],
				parts = vim.deepcopy(parts),
				dir = dir,
				files = files,
			})
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
