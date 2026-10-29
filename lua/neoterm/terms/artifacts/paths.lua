local config = require("neoterm.config")
local dirs = config.dirs
local M = {}

local function parts_under(root, path)
	local relative = vim.fs.relpath(root, vim.fs.abspath(path))
	return relative and vim.split(relative, "/", { plain = true, trimempty = true }) or nil
end

local function unique(paths)
	local seen, result = {}, {}
	for _, path in ipairs(paths) do
		if not seen[path] then
			seen[path] = true
			table.insert(result, path)
		end
	end
	table.sort(result)
	return result
end

local function location_key(path)
	path = vim.fs.normalize(vim.fs.abspath(path))
	return vim.uv.fs_realpath(path) or path
end

local function unique_locations(paths)
	local seen, result = {}, {}
	for _, path in ipairs(paths) do
		path = vim.fs.normalize(vim.fs.abspath(path))
		local key = location_key(path)
		if not seen[key] then
			seen[key] = true
			table.insert(result, path)
		end
	end
	table.sort(result)
	return result
end

function M.is_directory(path)
	local stat = vim.uv.fs_stat(path)
	return stat ~= nil and stat.type == "directory"
end

function M.project(checkout)
	local parts = assert(parts_under(dirs.projects, checkout), "Checkout is outside projects directory")
	return assert(parts[1], "Project name not found")
end

function M.project_artifacts(project)
	return vim.fs.joinpath(dirs.artifacts, project)
end

function M.artifact_project(path)
	local parts = parts_under(dirs.artifacts, path)
	return parts and parts[1] or nil
end

function M.checkout(project, branch)
	return vim.fs.joinpath(dirs.projects, project, branch)
end

function M.current_branch(checkout)
	local branch = vim.trim(vim.fn.system({ "git", "-C", checkout, "branch", "--show-current" }))
	if vim.v.shell_error == 0 and branch ~= "" then
		return branch
	end
end

function M.is_default(branch)
	return branch == nil or vim.tbl_contains(config.default_branches, branch)
end

local function source_name(path)
	local filename = vim.fs.basename(path)
	local names = { "task.md", "plan.md", "design.md", "index.md" }
	for _, step in ipairs(config.steps or {}) do
		vim.list_extend(names, type(step.source) == "table" and step.source or { step.source })
		if step.target then
			vim.list_extend(names, type(step.target) == "table" and step.target or { step.target })
		end
	end
	table.sort(names, function(a, b)
		return #a > #b
	end)
	for _, name in ipairs(names) do
		if filename == name or vim.endswith(filename, "." .. name) then
			return name
		end
	end
	return filename
end

function M.source(path, name)
	path = vim.fs.abspath(path)
	local parts = assert(parts_under(dirs.artifacts, path), "Source is outside artifacts directory")
	assert(#parts >= 2, "Artifact source must be inside a project")
	name = name or source_name(path)
	local filename = table.remove(parts)
	local project = table.remove(parts, 1)
	local prefix = filename ~= name
			and assert(filename:match("^(.*)%." .. vim.pesc(name) .. "$"), "Source name does not match artifact")
		or nil
	if prefix then
		table.insert(parts, prefix)
	end
	return {
		project = project,
		branch = #parts > 0 and table.concat(parts, "-") or config.default_branches[1],
		folder = vim.fs.dirname(path),
		file = path,
		source = name,
		identifier = prefix or vim.fs.basename(vim.fs.dirname(path)),
	}
end

function M.commit_message(path)
	assert(vim.fs.basename(path) == "task.md", "Commit messages require a task.md file")
	local parts = assert(parts_under(dirs.artifacts, path), "Task is outside artifacts directory")
	assert(#parts >= 3, "Task must be inside a named task directory")
	local branch = parts[#parts - 1]
	local prefix, change = branch:match("^(%a+)%-(.+)$")
	if
		not vim.tbl_contains(
			{ "feat", "fix", "build", "chore", "ci", "docs", "style", "refactor", "perf", "test", "revert" },
			prefix
		)
	then
		prefix, change = "feat", branch
	end
	local scope = #parts > 3 and "(" .. parts[#parts - 2]:gsub("-", " ") .. ")" or ""
	return prefix .. scope .. ": " .. change:gsub("-", " ")
end

function M.branch(source, fork, vars)
	local branch = source.branch
	assert(fork == nil or type(fork) == "boolean" or type(fork) == "string", "Fork must be a boolean or string")
	if type(fork) == "string" then
		local suffix = fork:gsub("{(.-)}", function(key)
			return assert((vars or {})[key], "Unknown fork template variable: " .. key)
		end)
		assert(suffix ~= "", "Fork suffix must not be empty")
		branch = branch .. "-" .. suffix
	end
	return branch
end

function M.step_name(source, step, variant)
	local parts = { step.name }
	if variant then
		table.insert(parts, variant)
	end
	table.insert(parts, source.branch)
	local sources = type(step.source) == "table" and step.source or { step.source }
	if vim.tbl_contains(sources, vim.fs.basename(source.file)) or source.identifier ~= source.branch then
		table.insert(parts, source.identifier)
	end
	return table.concat(parts, ":")
end

function M.branches(source, steps)
	local result = { source.branch }
	for _, step in ipairs(steps or config.steps or {}) do
		local sources = type(step.source) == "table" and step.source or { step.source }
		if vim.tbl_contains(sources, source.source) and (step.fork == true or type(step.fork) == "string") then
			for _, variant in ipairs(step.variants or { false }) do
				variant = variant or nil
				table.insert(
					result,
					M.branch(source, step.fork, { variant = variant, step = M.step_name(source, step, variant) })
				)
			end
		end
	end
	return unique(result)
end

function M.folder_branches(folder)
	local branches = { M.source(vim.fs.joinpath(folder, "task.md")).branch }
	if M.is_directory(folder) then
		for name, kind in vim.fs.dir(folder) do
			if kind == "file" then
				vim.list_extend(branches, M.branches(M.source(vim.fs.joinpath(folder, name))))
			end
		end
	end
	return unique(branches)
end

local function config_values(checkout, key)
	local output = vim.fn.systemlist({ "git", "-C", checkout, "config", "--local", "--get-all", key })
	return vim.v.shell_error == 0 and output or {}
end

local function links(checkout)
	local branch = M.current_branch(checkout)
	if not branch then
		return {}, {}
	end
	local key = "branch." .. branch
	local sources = config_values(checkout, key .. ".neoterm-artifact-source")
	local folders = config_values(checkout, key .. ".neoterm-artifacts")
	return unique_locations(sources), unique_locations(folders)
end

function M.link(checkout, folder, source)
	local project = M.project(checkout)
	assert(
		vim.fs.relpath(M.project_artifacts(project), vim.fs.abspath(folder)) ~= nil,
		"Artifact link must stay inside its project"
	)
	assert(
		source == nil or vim.fs.dirname(vim.fs.abspath(source)) == vim.fs.abspath(folder),
		"Artifact source must be inside its folder"
	)
	local branch = assert(M.current_branch(checkout), "Artifact checkout must have a branch")
	local key = "branch." .. branch .. (source and ".neoterm-artifact-source" or ".neoterm-artifacts")
	local value = vim.fs.abspath(source or folder)
	for _, existing in ipairs(config_values(checkout, key)) do
		if location_key(existing) == location_key(value) then
			return
		end
	end
	vim.fn.system({ "git", "-C", checkout, "config", "--local", "--add", key, value })
	assert(vim.v.shell_error == 0, "Failed to link checkout to artifacts")
end

function M.folders(project, branch)
	local root = M.project_artifacts(project)
	if M.is_default(branch) then
		return { root }
	end
	local folders = {}
	local normalized = branch:gsub("/", "-")
	if M.is_directory(root) then
		for path, kind in vim.fs.dir(root, { depth = math.huge }) do
			local full = vim.fs.joinpath(root, path)
			if kind == "directory" and path:gsub("/", "-") == normalized then
				table.insert(folders, full)
			elseif kind == "file" then
				local source = M.source(full)
				if vim.tbl_contains(M.branches(source), branch) then
					table.insert(folders, source.folder)
				end
			end
		end
	end
	return #folders > 0 and unique_locations(folders) or { vim.fs.joinpath(root, normalized) }
end

function M.artifact_folders(checkout)
	local sources, folders = links(checkout)
	for _, source in ipairs(sources) do
		table.insert(folders, vim.fs.dirname(source))
	end
	if #folders > 0 then
		return unique_locations(folders)
	end
	return M.folders(M.project(checkout), M.current_branch(checkout))
end

local function same_task(left, right)
	local a, b = M.source(left), M.source(right)
	return a.folder == b.folder and a.branch == b.branch
end

function M.preferred_folder(checkout)
	local root = M.project_artifacts(M.project(checkout))
	local selected, depth = root, -1
	for _, folder in ipairs(M.artifact_folders(checkout)) do
		if M.is_directory(folder) then
			local relative = assert(vim.fs.relpath(root, folder), "Artifact folder must stay inside its project")
			local count = relative == "." and 0 or #vim.split(relative, "/", { plain = true, trimempty = true })
			if count > depth then
				selected, depth = folder, count
			end
		end
	end
	return selected, depth >= 0
end

function M.artifact_files(checkout)
	local sources, linked_folders = links(checkout)
	local branch = M.current_branch(checkout)
	local files = {}
	for _, folder in ipairs(M.artifact_folders(checkout)) do
		if M.is_directory(folder) then
			for path, kind in vim.fs.dir(folder, { depth = math.huge }) do
				if kind == "file" then
					local file = vim.fs.joinpath(folder, path)
					local matches = #sources == 0
						and #linked_folders == 0
						and (M.is_default(branch) or vim.tbl_contains(M.branches(M.source(file)), branch))
					for _, source in ipairs(sources) do
						matches = matches or same_task(source, file)
					end
					for _, linked in ipairs(linked_folders) do
						matches = matches or vim.fs.relpath(linked, file) ~= nil
					end
					if matches then
						table.insert(files, file)
					end
				end
			end
		end
	end
	return unique_locations(files)
end

function M.default_checkout(project)
	for _, branch in ipairs(config.default_branches) do
		local path = M.checkout(project, branch)
		if M.is_directory(path) then
			return path
		end
	end
	local root = vim.fs.joinpath(dirs.projects, project)
	return M.is_directory(root) and root or nil
end

local function checkouts(path, get_links)
	path = vim.fs.abspath(path)
	local parts = parts_under(dirs.artifacts, path)
	if not parts or not parts[1] then
		return {}
	end
	local project = parts[1]
	local root = vim.fs.joinpath(dirs.projects, project)
	local directory = M.is_directory(path)
	local names = {}
	if directory then
		names = M.folder_branches(path)
	else
		names = M.branches(M.source(path))
	end
	local candidates = {}
	if M.is_directory(root) then
		for name, kind in vim.fs.dir(root) do
			if kind == "directory" then
				local checkout = vim.fs.joinpath(root, name)
				local sources, folders = get_links(checkout)
				local matches = #sources == 0 and #folders == 0 and vim.tbl_contains(names, name)
				for _, source in ipairs(sources) do
					matches = matches
						or (directory and vim.fs.relpath(path, source) ~= nil)
						or (not directory and same_task(source, path))
				end
				for _, folder in ipairs(folders) do
					matches = matches or vim.fs.relpath(folder, path) ~= nil
				end
				if matches then
					table.insert(candidates, checkout)
				end
			end
		end
	end
	if #candidates > 0 then
		return unique_locations(candidates)
	end
	for count = #parts - 1, 2, -1 do
		local checkout = M.checkout(project, table.concat(parts, "-", 2, count))
		if M.is_directory(checkout) then
			local sources, folders = get_links(checkout)
			if #sources == 0 and #folders == 0 then
				return { checkout }
			end
		end
	end
	local fallback = M.default_checkout(project)
	return fallback and { fallback } or {}
end

function M.checkouts(path)
	return checkouts(path, links)
end

function M.checkout_resolver()
	local cache = {}
	return function(path)
		return checkouts(path, function(checkout)
			if cache[checkout] == nil then
				cache[checkout] = { links(checkout) }
			end
			return unpack(cache[checkout])
		end)
	end
end

return M
