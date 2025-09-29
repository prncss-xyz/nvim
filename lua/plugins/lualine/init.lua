local not_vscode = require("my.conds").not_vscode

return {
	{
		"nvim-lualine/lualine.nvim",
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
				lualine_a = { "branch" },
				lualine_b = { require("plugins.lualine.file") },
				lualine_c = { require("plugins.lualine.overseer") },
				lualine_x = { require("plugins.lualine.coordinates") },
				lualine_y = {},
				lualine_z = {},
			},
		},
		dependencies = "MunifTanjim/nui.nvim",
		cond = not_vscode,
	},
}
