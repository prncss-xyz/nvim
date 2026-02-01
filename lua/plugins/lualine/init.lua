local not_vscode = require("my.conds").not_vscode

local function starship()
	local handle = io.popen("starship prompt --status=0 --jobs=0")
	if not handle then
		return ""
	end
	local result = handle:read("*a")
	handle:close()
	if not result then
		return ""
	end
	-- Strip ANSI colors
	result = result:gsub("\27%[[0-9;]*m", "")
	-- Flatten and trim
	return result:gsub("\n", " "):gsub("^%s*(.-)%s*$", "%1")
end

return {
	{
		"nvim-lualine/lualine.nvim",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		event = "VeryLazy",
		opts = {
			options = {
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
				always_divide_middle = false,
				globalstatus = true,
				always_show_tabline = false,
			},
			tabline = {
				lualine_a = {},
			},
			sections = {
				lualine_a = { starship },
				lualine_b = { require("plugins.lualine.file") },
				lualine_c = {},
				lualine_x = { require("plugins.lualine.coordinates") },
				lualine_y = {},
				lualine_z = {},
			},
		},
		cond = not_vscode,
	},
}
