local M = {}

-- TODO: package manager is last of kind (must be possible to extend to other langs)

local checks = {
	{ "pnpm-lock.yaml", "pnpm" },
	{ "package-lock.json", "npm" },
	{ "yarn.lock", "yarn" },
	{ "bun.lockb", "bun" },
}

local function get_npm(root, field)
	if field then
		return field:gsub("@.*", "")
	end
	-- Fallback to checking common lockfiles
	for _, c in ipairs(checks) do
		if vim.fn.filereadable(root .. "/" .. c[1]) == 1 then
			return c[2]
		end
	end
end

local function from_package(opts, prefix, acc)
	local root = opts.root
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

	local npm = get_npm(root, pkg.packageManager) or opts.npm

	for name, _ in pairs(pkg.scripts) do
		local cmd = string.format("%s run %s", npm, name)
		local key = cmd
		if #prefix > 0 then
			key = key .. string.format(" (%s)", prefix)
		end
		local tag = require("plugins.toggleterm.config").packages
			and require("plugins.toggleterm.config").packages.tagger
			and require("plugins.toggleterm.config").packages.tagger(key)
		table.insert(acc, {
			key = key,
			conf = {
				cmd = cmd,
				cwd = root .. prefix,
				tag = tag,
			},
		})
	end

	return npm
end

local function should_skip(name)
	return name == "node_modules" or vim.startswith(name, ".")
end

local function walk(opts, prefix, depth, acc)
	local root = opts.root
	local npm = from_package(opts, prefix, acc)
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
				local new_opts = vim.tbl_extend("force", opts, { npm = npm })
				walk(new_opts, next_prefix, depth + 1, acc)
			end
		end
	end
end

function M.add_npm_scripts(acc)
	walk({ root = vim.fn.getcwd() }, "", 0, acc)
end

function M.find(key)
	local acc = {}
	walk({ root = vim.fn.getcwd() }, "", 0, acc)
	for _, item in ipairs(acc) do
		if item.key == key then
			return item.conf
		end
	end
end

return M
