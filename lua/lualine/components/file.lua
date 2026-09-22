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

local function file_buffer(win)
	if
		not vim.api.nvim_win_is_valid(win)
		or vim.api.nvim_win_get_tabpage(win) ~= vim.api.nvim_get_current_tabpage()
	then
		return
	end
	local buffer = vim.api.nvim_win_get_buf(win)
	-- Files opened with nvim_win_set_buf() can remain unlisted.
	if vim.bo[buffer].buftype == "" then
		return buffer
	end
end

local function displayed_buffer()
	local win = vim.api.nvim_get_current_win()
	local current = file_buffer(win)
	if current then
		-- Window changes refresh lualine synchronously, so no separate history is needed.
		vim.t.lualine_file_win = win
		return current
	end
	local previous = vim.t.lualine_file_win
	local buffer = previous and file_buffer(previous)
	if buffer then
		return buffer
	end
	-- Lualine may load after a panel has already taken focus.
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buffer = file_buffer(win)
		if buffer then
			vim.t.lualine_file_win = win
			return buffer
		end
	end
end

return function()
	local buffer = displayed_buffer()
	if not buffer then
		return ""
	end

	local path = vim.api.nvim_buf_get_name(buffer)
	local name = path == "" and "[No Name]" or get_displayed_name(path)
	return get_file_icon(buffer, path) .. name .. " " .. get_status_icons(buffer, path) .. "  "
end
