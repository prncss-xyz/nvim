local M = {}
local configured_schemes = {}

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

function M.register_colorschemes(names)
	if type(names) == "string" then
		configured_schemes[names] = true
	elseif names.dark then
		local dark = type(names.dark) == "string" and { names.dark } or names.dark
		local light = type(names.light) == "string" and { names.light } or names.light
		for index, name in ipairs(dark) do
			configured_schemes[name] = "dark"
			configured_schemes[light[index]] = "light"
		end
	else
		for _, name in ipairs(names) do
			configured_schemes[name] = true
		end
	end
end

function M.pick_colorscheme()
	local background = vim.o.background
	Snacks.picker.colorschemes({
		finder = function()
			local items = require("snacks.picker.source.vim").colorschemes()
			return vim.tbl_filter(function(item)
				local variant = configured_schemes[item.text]
				return variant == true or variant == background
			end, items)
		end,
	})
end

return M
