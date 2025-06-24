local M = {}

local module = "my/theme"
local theme_file = vim.fn.stdpath("config") .. "/lua/" .. module .. ".lua"

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
	return file_exists(theme_file) and require(module) or {}
end

function M.save_theme()
	local file = io.open(theme_file, "w")
	if file then
		local colors_name = vim.g.colors_name
		local background = vim.o.background
		file:write(string.format(
			[[return {
  colors_name = %q,
  background = %q,
}
]],
			colors_name,
			background
		))
		file:close()
	else
		print("error!")
	end
end

return M
