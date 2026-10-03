local M = {}
local configured_schemes = {}
local rotating_schemes = {}
local zone_schemes = {}
local next_scheme = 1
local active_zone
local applying_zone_theme = false

local function add_scheme(dark, light)
	table.insert(rotating_schemes, { dark = dark, light = light })
end

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
		add_scheme(names, names)
	elseif names.dark then
		local dark = type(names.dark) == "string" and { names.dark } or names.dark
		local light = type(names.light) == "string" and { names.light } or names.light
		for index, name in ipairs(dark) do
			configured_schemes[name] = "dark"
			configured_schemes[light[index]] = "light"
			add_scheme(name, light[index])
		end
	else
		for _, name in ipairs(names) do
			configured_schemes[name] = true
			add_scheme(name, name)
		end
	end
end

function M.set_zone_theme(zone)
	active_zone = zone
	local scheme = zone_schemes[zone]
	if not scheme then
		if #rotating_schemes == 0 then
			return
		end
		scheme = rotating_schemes[next_scheme]
		zone_schemes[zone] = scheme
		next_scheme = next_scheme % #rotating_schemes + 1
	end
	local background = vim.o.background
	local name = scheme[background]
	if vim.g.colors_name ~= name then
		applying_zone_theme = true
		vim.cmd.colorscheme(name)
		-- Some colorschemes set 'background' themselves.
		vim.o.background = background
		applying_zone_theme = false
	end
end

function M.remember_current_theme(name)
	if not active_zone or applying_zone_theme then
		return
	end
	for _, scheme in ipairs(rotating_schemes) do
		if scheme.dark == name or scheme.light == name then
			zone_schemes[active_zone] = scheme
			return
		end
	end
	zone_schemes[active_zone] = { dark = name, light = name }
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
