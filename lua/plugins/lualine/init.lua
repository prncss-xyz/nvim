local not_vscode = require("my.conds").not_vscode

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
				lualine_a = { "starship" },
				lualine_b = { "file" },
				lualine_c = {},
				lualine_x = { "coordinates" },
				lualine_y = {},
				lualine_z = {},
			},
		},
		cond = not_vscode,
	},
}
