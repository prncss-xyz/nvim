local files = require("plugins.toggleterm.templates.files")

local manager_lockfiles = {
	npm = { "package-lock.json" },
	pnpm = { "pnpm-lock.yaml" },
	yarn = { "yarn.lock" },
	bun = { "bun.lockb", "bun.lock" },
}

local function get_candidate_package_files(opts)
	local matches = vim.fs.find("package.json", {
		upward = true,
		type = "file",
		path = opts.dir,
		stop = vim.fn.getcwd() .. "/..",
		limit = math.huge,
	})
	if #matches > 0 then
		return matches
	end
	return vim.fs.find("package.json", {
		upward = true,
		type = "file",
		path = vim.fn.getcwd(),
	})
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

		if vim.islist(data.workspaces) then
			for _, workspace in ipairs(data.workspaces) do
				local workspace_path = vim.fs.joinpath(cwd, workspace)
				local workspace_data = files.load_json_file(vim.fs.joinpath(workspace_path, "package.json"))
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
