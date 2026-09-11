local function get_mise_file(opts)
	local function is_mise_file(name)
		name = name:lower()
		return name:match("^%.?mise%.toml$") ~= nil
			or name:match("^%.?mise%.local%.toml$") ~= nil
			or name:match("^%.?mise%.%w+%.toml$") ~= nil
			or name:match("^%.?mise%.%w+%.local%.toml$") ~= nil
	end

	local function is_mise_dir(name)
		name = name:lower()
		return name:match("^%.?mise$") ~= nil or name:match("^%.?mise%-tasks$") ~= nil or name == ".config"
	end

	return vim.fs.find(is_mise_file, { type = "file", upward = true, path = opts.dir })[1]
		or vim.fs.find(is_mise_dir, { type = "directory", upward = true, path = opts.dir })[1]
end

return {
	generator = function(opts)
		if vim.fn.executable("mise") == 0 then
			return 'Command "mise" not found'
		end
		local mise_file = get_mise_file(opts)
		if not mise_file then
			return "No mise file or directory found"
		end

		local cwd = vim.fs.dirname(mise_file)
		local out = vim.system({ "mise", "tasks", "--json" }, { cwd = cwd, text = true }):wait()
		local ok, data = pcall(vim.json.decode, out.stdout or "", { luanil = { object = true } })
		if not ok then
			return data
		end

		local definitions = {}
		for _, value in pairs(data) do
			local name = value.name
			table.insert(definitions, {
				name = string.format("mise %s", name),
				desc = value.description ~= "" and value.description or nil,
				builder = function()
					return { cmd = { "mise", "run", name }, cwd = cwd }
				end,
			})
		end
		return definitions
	end,
}
