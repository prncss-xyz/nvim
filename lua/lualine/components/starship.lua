local values = {}
local refreshing_cwd
local last_refresh = {}
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

local function refresh(cwd)
	local now = vim.uv.now()
	if refreshing_cwd or now - (last_refresh[cwd] or -math.huge) < throttle_ms then
		return
	end

	refreshing_cwd = cwd
	last_refresh[cwd] = now

	vim.system(
		{ "starship", "prompt", "--status=0", "--jobs=0" },
		{ cwd = cwd, text = true, env = { PWD = cwd } },
		function(result)
			local value = result.code == 0 and format_prompt(result.stdout or "") or ""
			if value == "" then
				value = cwd_name(cwd)
			end

			vim.schedule(function()
				refreshing_cwd = nil
				local changed = values[cwd] ~= value
				values[cwd] = value

				local current_cwd = vim.fn.getcwd()
				if current_cwd ~= cwd then
					refresh(current_cwd)
				elseif changed then
					require("lualine").refresh()
				end
			end)
		end
	)
end

return function()
	local cwd = vim.fn.getcwd()
	if vim.fn.executable("starship") ~= 1 then
		return cwd_name(cwd)
	end

	refresh(cwd)
	return values[cwd] or cwd_name(cwd)
end
