local last_value
local refreshing = false
local last_refresh = -math.huge
local throttle_ms = 500

local function cwd_name(cwd)
	cwd = cwd or vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	return name ~= "" and name or cwd
end

local function format_prompt(output)
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
end

local function refresh()
	local now = vim.uv.now()
	if refreshing or now - last_refresh < throttle_ms then
		return
	end

	refreshing = true
	last_refresh = now
	local cwd = vim.fn.getcwd()

	vim.system({ "starship", "prompt", "--status=0", "--jobs=0" }, { cwd = cwd, text = true }, function(result)
		local value = result.code == 0 and format_prompt(result.stdout or "") or ""
		if value == "" then
			value = cwd_name(cwd)
		end

		vim.schedule(function()
			last_value = value
			refreshing = false
			require("lualine").refresh()
		end)
	end)
end

return function()
	if vim.fn.executable("starship") ~= 1 then
		return cwd_name()
	end

	refresh()
	return last_value
end
