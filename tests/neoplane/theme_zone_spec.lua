local MiniTest = require("mini.test")
local T = MiniTest.new_set()

T["zones rotate themes and retain their dark or light variant"] = function()
	local original_theme = package.loaded["my.theme_utils"]
	local original_background = vim.o.background
	local original_scheme = vim.g.colors_name
	local original_stdpath = vim.fn.stdpath
	local state_dir = vim.fn.tempname()
	vim.fn.mkdir(state_dir, "p")
	vim.fn.stdpath = function(kind)
		return kind == "state" and state_dir or original_stdpath(kind)
	end
	package.loaded["my.theme_utils"] = nil
	local themes = require("my.theme_utils")
	local ok, err = pcall(function()
		themes.register_colorschemes({ dark = "habamax", light = "morning" })
		themes.register_colorschemes({ dark = "evening", light = "peachpuff" })
		vim.o.background = "dark"
		themes.set_zone_theme("/one")
		assert.same("habamax", vim.g.colors_name)
		themes.set_zone_theme("/two")
		assert.same("evening", vim.g.colors_name)
		themes.set_zone_theme("/three")
		assert.same("habamax", vim.g.colors_name)
		vim.o.background = "light"
		themes.set_zone_theme("/two")
		assert.same("peachpuff", vim.g.colors_name)
		themes.set_zone_theme("/one")
		assert.same("morning", vim.g.colors_name)
		vim.cmd.colorscheme("peachpuff")
		themes.remember_current_theme(vim.g.colors_name)
		themes.set_zone_theme("/three")
		themes.set_zone_theme("/one")
		assert.same("peachpuff", vim.g.colors_name)
		assert.same({ dark = "evening", light = "peachpuff" }, themes.load_theme()["/one"])
		package.loaded["my.theme_utils"] = nil
		local restored = require("my.theme_utils")
		assert.same("peachpuff", restored.theme_for_zone("/one"))
		vim.o.background = "dark"
		assert.same("evening", restored.theme_for_zone("/one"))
	end)
	package.loaded["my.theme_utils"] = original_theme
	vim.fn.stdpath = original_stdpath
	vim.fn.delete(state_dir, "rf")
	vim.o.background = original_background
	if original_scheme then
		vim.cmd.colorscheme(original_scheme)
	end
	if not ok then
		error(err)
	end
end

return T
