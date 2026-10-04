local not_vscode = require("my.conds").not_vscode
local domain = require("my.parameters").domain

local theme_utils = require("my.theme_utils")
local theme = theme_utils.theme_for_zone(vim.fn.getcwd())
local paired_schemes = {}
local switching = false

local function as_list(value)
	return type(value) == "string" and { value } or value
end

local function switch_background()
	if switching then
		return
	end
	local current = vim.g.colors_name
	local pair = paired_schemes[current]
	if not pair then
		return
	end
	local target_background = vim.o.background
	local target = pair[target_background]
	if target == current then
		return
	end
	switching = true
	vim.cmd.colorscheme(target)
	vim.o.background = target_background
	switching = false
end

local function set_background(background)
	vim.o.background = background
	switch_background()
end

local function find(value, tbl)
	if type(tbl) == "string" then
		return tbl == value
	end
	for _, v in ipairs(tbl) do
		if v == value then
			return true
		end
	end
	return false
end

local function colorscheme(names, config)
	theme_utils.register_colorschemes(names)
	if names.dark then
		local dark = as_list(names.dark)
		local light = as_list(names.light)
		assert(#dark == #light, "dark and light colorscheme lists must have the same length")
		for index, name in ipairs(dark) do
			paired_schemes[name] = { dark = name, light = light[index] }
		end
		for index, name in ipairs(light) do
			paired_schemes[name] = { dark = dark[index], light = name }
		end
		names = vim.list_extend(vim.deepcopy(dark), light)
	end
	config.cond = not_vscode
	if theme and find(theme, names) then
		config.priority = 1000
		config.lazy = false
		config.dependencies = {
			{
				"f-person/auto-dark-mode.nvim",
				opts = {
					set_dark_mode = function()
						set_background("dark")
					end,
					set_light_mode = function()
						set_background("light")
					end,
				},
			},
		}
		function config.config()
			vim.cmd.colorscheme(theme)
			switch_background()
		end
	end
	return config
end

return {
	colorscheme({ "catppuccin-nvim" }, {
		"catppuccin/nvim",
		name = "catppuccin",
		commit = "0303a7208dba448c459767486a38a6ec05c4216b",
	}),
	-- dark-only
	colorscheme("luna", {
		"WTFox/luna.nvim",
		commit = "b6f25f10012df3f29ca56e78d40e53a392e7f98f",
	}),
	-- dark-only
	colorscheme("selenized", {
		"calind/selenized.nvim",
		commit = "a43e34d",
	}),
	colorscheme({ dark = "kanagawa", light = "kanagawa-lotus" }, {
		"rebelot/kanagawa.nvim",
	}),
	colorscheme("gruvbox", {
		"ellisonleao/gruvbox.nvim",
	}),
	colorscheme({ "solarized" }, {
		"ishan9299/nvim-solarized-lua",
		commit = "d69a263",
	}),
	colorscheme({ dark = "cyberdream", light = "cyberdream-light" }, {
		"scottmckendry/cyberdream.nvim",
	}),
	colorscheme("e-ink", {
		"e-ink-colorscheme/e-ink.nvim",
		commit = "c90bf52",
	}),
	{
		"xiyaowong/transparent.nvim",
		event = "ColorScheme",
		commit = "8ac5988",
		config = function()
			require("transparent").setup({
				exclude_groups = { "StatusLine", "StatusLineNC" },
			})
		end,
		keys = {
			{
				domain.appearance .. "g",
				function()
					set_background(vim.o.background == "light" and "dark" or "light")
				end,
				desc = "Toggle Light",
			},
			{
				domain.appearance .. "o",
				function()
					vim.cmd("TransparentToggle")
				end,
				desc = "Toggle Transparent",
			},
		},
	},
}
