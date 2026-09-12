local M = {}

local function files_in(dir)
	local files = {}
	for name, kind in vim.fs.dir(dir) do
		if kind == "file" then
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

	for project, project_kind in vim.fs.dir(root) do
		if project_kind == "directory" then
			local project_dir = vim.fs.joinpath(root, project)
			for branch, branch_kind in vim.fs.dir(project_dir) do
				if branch_kind == "directory" then
					local dir = vim.fs.joinpath(project_dir, branch)
					local files = files_in(dir)
					local status = statuses[1].name
					for _, candidate in ipairs(statuses) do
						for _, filename in ipairs(candidate.files or {}) do
							if files[vim.fs.joinpath(dir, filename)] then
								status = candidate.name
							end
						end
					end
					local index = vim.fs.joinpath(dir, "index.md")
					if files[index] then
						local explicit = require("plugins.toggleterm.yaml").read_file(index).status
						if explicit ~= nil then
							assert(status_names[explicit], "Unknown artifact task status: " .. tostring(explicit))
							status = explicit
						end
					end
					table.insert(tasks, {
						status = status,
						project = project,
						branch = branch,
						dir = dir,
						files = files,
					})
				end
			end
		end
	end
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
