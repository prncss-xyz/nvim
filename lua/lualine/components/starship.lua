local function cwd_name()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	return name ~= "" and name or cwd
end

return function()
	if vim.fn.executable("starship") ~= 1 then
		return cwd_name()
	end

	local ok, result = pcall(function()
		local handle = io.popen("starship prompt --status=0 --jobs=0 2>/dev/null")
		if not handle then
			return ""
		end
		local output = handle:read("*a")
		handle:close()
		if not output then
			return ""
		end
		-- Strip all ANSI escape sequences
		output = output:gsub("\27%[[^a-zA-Z]*[a-zA-Z]", "")
		-- Join non-empty lines and trim
		local parts = {}
		for line in output:gmatch("[^\n]+") do
			local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
			if trimmed ~= "" then
				parts[#parts + 1] = trimmed
			end
		end
		return table.concat(parts, " ")
	end)
	return ok and result ~= "" and result or cwd_name()
end
