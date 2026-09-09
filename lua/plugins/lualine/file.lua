local unknown_icon = ""
local skip_lock = {}
local user_icons = {}

local function get_file_icon(buffer, path)
	local ok, devicons = pcall(require, "nvim-web-devicons")
	if not ok then
		return ""
	end

	local filename = vim.fs.basename(path)
	local extension = filename:match("%.([^.]*)$")
	local icon = devicons.get_icon(filename, extension)
		or (user_icons[vim.bo[buffer].filetype] and user_icons[vim.bo[buffer].filetype][2])
		or (user_icons[extension] and user_icons[extension][2])
		or unknown_icon
	return icon .. " "
end

local function get_displayed_name(path)
	local cwd = vim.fn.getcwd()
	local relative = vim.fs.relpath(cwd, path)
	if relative then
		return relative
	end

	local home = vim.env.HOME
	if home then
		local home_relative = vim.fs.relpath(home, path)
		if home_relative then
			return "~/" .. home_relative
		end
	end
	return path
end

local function get_diagnostic(buffer)
	local result = {}
	for _, diagnostic in ipairs(vim.diagnostic.get(buffer)) do
		result[diagnostic.severity] = (result[diagnostic.severity] or 0) + 1
	end
	return result
end

local function get_global_diagnostic()
	local result = {}
	for _, diagnostic in ipairs(vim.diagnostic.get()) do
		result[diagnostic.severity] = (result[diagnostic.severity] or 0) + 1
	end
	return result
end

local function diagnostic_icon(diagnostics)
	if diagnostics[vim.diagnostic.severity.ERROR] then
		return ""
	end
	if diagnostics[vim.diagnostic.severity.WARN] then
		return ""
	end
	return " "
end

local function get_status_icons(buffer, path)
	local icons = {}
	if path ~= "" and vim.bo[buffer].modifiable and vim.bo[buffer].modified then
		icons[#icons + 1] = ""
	end
	if vim.tbl_contains(skip_lock, vim.bo[buffer].filetype) and vim.bo[buffer].readonly then
		icons[#icons + 1] = ""
	end
	icons[#icons + 1] = diagnostic_icon(get_global_diagnostic())
	icons[#icons + 1] = diagnostic_icon(get_diagnostic(buffer))
	return "  " .. table.concat(icons, " ")
end

local last_value = ""

return function()
	local buffer = vim.api.nvim_get_current_buf()
	if vim.bo[buffer].buftype ~= "" or not vim.bo[buffer].buflisted then
		return last_value
	end

	local path = vim.api.nvim_buf_get_name(buffer)
	local name = path == "" and "[No Name]" or get_displayed_name(path)
	last_value = get_file_icon(buffer, path) .. name .. " " .. get_status_icons(buffer, path) .. "  "
	return last_value
end
