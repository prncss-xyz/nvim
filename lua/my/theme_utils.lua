local M = {}

local theme_file = vim.fn.stdpath("state") .. "theme.json"
local function file_exists(path)
	local f = io.open(path, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

function M.load_theme()
	if not file_exists(theme_file) then
		return {}
	end
	local file = io.open(theme_file, "r")
	if not file then
		return {}
	end
	local ok, data = pcall(vim.json.decode, file:read("*a"))
	file:close()
	return ok and data or {}
end

function M.save_theme()
	local file = io.open(theme_file, "w")
	if file then
		local colors_name = vim.g.colors_name
		file:write(vim.json.encode({
			colors_name = colors_name,
		}))
		file:close()
	else
		print("error!")
	end
end

return M
