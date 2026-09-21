local async = require("neoterm.helpers.term_templates")

local manager_lockfiles = {
	npm = { "package-lock.json" },
	pnpm = { "pnpm-lock.yaml" },
	yarn = { "yarn.lock" },
	bun = { "bun.lockb", "bun.lock" },
}

local function detect_package_manager(package_dir, package, callback)
	if package.packageManager then
		return callback(package.packageManager:gsub("@.*", ""))
	end

	local checks = {}
	for manager, lockfiles in pairs(manager_lockfiles) do
		for _, lockfile in ipairs(lockfiles) do
			table.insert(checks, { manager = manager, path = vim.fs.joinpath(package_dir, lockfile) })
		end
	end
	local pending = #checks
	local found
	for _, check in ipairs(checks) do
		async.stat(check.path, function(stat)
			if not found and stat and stat.type == "file" then
				found = check.manager
			end
			pending = pending - 1
			if pending == 0 then
				callback(found)
			end
		end)
	end
end

local function find_package(candidate_packages, callback)
	local index = 1
	local fallback
	local function next_candidate()
		local package_file = candidate_packages[index]
		if package_file == nil then
			return callback(fallback, fallback and "npm" or nil)
		end
		index = index + 1
		async.read_json(package_file, function(data)
			if not data or (not data.scripts and not data.workspaces) then
				return next_candidate()
			end
			fallback = fallback or package_file
			detect_package_manager(vim.fs.dirname(package_file), data, function(manager)
				if manager then
					return callback(package_file, manager, data)
				end
				next_candidate()
			end)
		end)
	end
	next_candidate()
end

local function add_scripts(definitions, data, manager, cwd, workspace)
	for script in pairs(data.scripts or {}) do
		local name = workspace and string.format("%s[%s] %s", manager, workspace, script)
			or string.format("%s %s (%s)", manager, script, data.name or vim.fs.basename(cwd))
		table.insert(definitions, {
			name = name,
			builder = function()
				return { cmd = { manager, "run", script }, cwd = cwd }
			end,
		})
	end
end

return {
	generator = function(opts, callback)
		local cwd = opts.cwd or opts.dir
		async.find_up("package.json", cwd, 2, function(candidates)
			local function use_candidates(package_files)
				find_package(package_files, function(package_file, manager, package_data)
					if not package_file then
						return callback("No package.json file found")
					end
					async.executable(manager, function(installed)
						if not installed then
							return callback(string.format("Could not find command '%s'", manager))
						end
						local root = vim.fs.dirname(package_file)
						local function finish(data)
							local definitions = {}
							add_scripts(definitions, data, manager, root)
							async.walk_files(root, 2, {
								match = function(name)
									return name == "package.json"
								end,
								skip_dir = function(name)
									return name == "node_modules" or vim.startswith(name, ".")
								end,
							}, function(package_files)
								local workspaces = {}
								for _, path in ipairs(package_files) do
									if path ~= package_file then
										table.insert(workspaces, path)
									end
								end
								local pending = #workspaces
								local function complete()
									table.insert(definitions, {
										name = manager .. " install",
										builder = function()
											return { cmd = { manager, "install" }, cwd = root }
										end,
									})
									callback(definitions)
								end
								if pending == 0 then
									return complete()
								end
								for _, path in ipairs(workspaces) do
									async.read_json(path, function(workspace_data)
										if workspace_data then
											add_scripts(
												definitions,
												workspace_data,
												manager,
												vim.fs.dirname(path),
												assert(vim.fs.relpath(root, vim.fs.dirname(path)))
											)
										end
										pending = pending - 1
										if pending == 0 then
											complete()
										end
									end)
								end
							end)
						end
						if package_data then
							finish(package_data)
						else
							async.read_json(package_file, finish)
						end
					end)
				end)
			end
			if #candidates > 0 then
				return use_candidates(candidates)
			end
			async.walk_files(cwd, 2, {
				match = function(name)
					return name == "package.json"
				end,
				skip_dir = function(name)
					return name == "node_modules" or vim.startswith(name, ".")
				end,
			}, use_candidates)
		end)
	end,
}
