local M = {}

-- TODO: package manager is last of kind (must be possible to extend to other langs)
-- TODO: add function to create tag

local checks = {
	{ "pnpm-lock.yaml", "pnpm" },
	{ "package-lock.json", "npm" },
	{ "yarn.lock", "yarn" },
	{ "bun.lockb", "bun" },
}

local function get_manager(root)
	-- Fallback to checking common lockfiles
	for _, c in ipairs(checks) do
		if vim.fn.filereadable(root .. "/" .. c[1]) == 1 then
			return c[2]
		end
	end
	return "npm"
end

local function from_package(root, prefix, acc)
	local pkg_path = root .. prefix .. "/package.json"
	if vim.fn.filereadable(pkg_path) == 0 then
		return nil
	end

	local lines = vim.fn.readfile(pkg_path)
	if not lines then
		return nil
	end

	local ok, pkg = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
	if not ok or type(pkg) ~= "table" then
		return nil
	end

	if not pkg.scripts or type(pkg.scripts) ~= "table" then
		return nil
	end

	local manager = pkg.packageManager or get_manager(root)
	manager = manager:gsub("@.*", "")

	for name, _ in pairs(pkg.scripts) do
		local cmd = string.format("%s run %s", manager, name)
		local key = cmd
		if #prefix > 0 then
			key = key .. string.format(" (%s)", prefix)
		end
		table.insert(acc, {
			key = key,
			conf = {
				cmd = cmd,
				cwd = root .. prefix,
			},
		})
	end
end

local function should_skip(name)
	return name == "node_modules" or vim.startswith(name, ".")
end

local function walk(root, prefix, depth, acc)
	from_package(root, prefix, acc)
	if depth >= 2 then
		return
	end

	local dir = root .. prefix
	local entries = vim.fn.readdir(dir)
	if type(entries) ~= "table" then
		return
	end

	for _, name in ipairs(entries) do
		if not should_skip(name) then
			local next_prefix = prefix .. "/" .. name
			if vim.fn.isdirectory(root .. next_prefix) == 1 then
				walk(root, next_prefix, depth + 1, acc)
			end
		end
	end
end

function M.add_npm_scripts(acc)
	walk(vim.fn.getcwd(), "", 0, acc)
end

return M
