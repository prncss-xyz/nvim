local files = require("plugins.toggleterm.terms.files")

local manager_lockfiles = {
	npm = { "package-lock.json" },
	pnpm = { "pnpm-lock.yaml" },
	yarn = { "yarn.lock" },
	bun = { "bun.lockb", "bun.lock" },
}

local function get_candidate_package_files(opts)
	local matches = {}
	local dir = vim.fs.abspath(opts.dir)
	for _ = 0, 2 do
		local package = vim.fs.joinpath(dir, "package.json")
		if vim.fn.filereadable(package) == 1 then
			table.insert(matches, package)
		end
		local parent = vim.fs.dirname(dir)
		if parent == dir then
			break
		end
		dir = parent
	end
	return matches
end

local function detect_package_manager(package_dir, package)
	if package.packageManager then
		return package.packageManager:gsub("@.*", "")
	end
	for manager, lockfiles in pairs(manager_lockfiles) do
		for _, lockfile in ipairs(lockfiles) do
			if vim.uv.fs_stat(vim.fs.joinpath(package_dir, lockfile)) then
				return manager
			end
		end
	end
end

local function descendant_packages(root, max_depth)
	local packages = {}
	local function scan(dir, depth)
		if depth > max_depth then
			return
		end
		for name, kind in vim.fs.dir(dir) do
			if kind == "directory" and name ~= "node_modules" and not vim.startswith(name, ".") then
				local child = vim.fs.joinpath(dir, name)
				local package = vim.fs.joinpath(child, "package.json")
				if vim.fn.filereadable(package) == 1 then
					table.insert(packages, package)
				end
				scan(child, depth + 1)
			end
		end
	end
	scan(root, 1)
	table.sort(packages)
	return packages
end

local function get_package_and_manager(candidate_packages)
	for _, package_file in ipairs(candidate_packages) do
		local data = files.load_json_file(package_file)
		if data and (data.scripts or data.workspaces) then
			local manager = detect_package_manager(vim.fs.dirname(package_file), data)
			if manager then
				return package_file, manager
			end
		end
	end
	for _, package_file in ipairs(candidate_packages) do
		local data = files.load_json_file(package_file)
		if data and (data.scripts or data.workspaces) then
			return package_file, "npm"
		end
	end
end

return {
	generator = function(opts)
		local package, manager = get_package_and_manager(get_candidate_package_files(opts))
		if not package then
			return "No package.json file found"
		end
		if vim.fn.executable(manager) == 0 then
			return string.format("Could not find command '%s'", manager)
		end

		local data = assert(files.load_json_file(package))
		local cwd = vim.fs.dirname(package)
		local definitions = {}
		if data.scripts then
			for script in pairs(data.scripts) do
				table.insert(definitions, {
					name = string.format("%s %s (%s)", manager, script, data.name or vim.fs.basename(cwd)),
					builder = function()
						return { cmd = { manager, "run", script }, cwd = cwd }
					end,
				})
			end
		end

		for _, workspace_package in ipairs(descendant_packages(cwd, 2)) do
			local workspace_path = vim.fs.dirname(workspace_package)
			local workspace = assert(vim.fs.relpath(cwd, workspace_path))
			local workspace_data = files.load_json_file(workspace_package)
			if workspace_data and workspace_data.scripts then
				for script in pairs(workspace_data.scripts) do
					table.insert(definitions, {
						name = string.format("%s[%s] %s", manager, workspace, script),
						builder = function()
							return { cmd = { manager, "run", script }, cwd = workspace_path }
						end,
					})
				end
			end
		end

		table.insert(definitions, {
			name = manager .. " install",
			builder = function()
				return { cmd = { manager, "install" }, cwd = cwd }
			end,
		})
		return definitions
	end,
}
