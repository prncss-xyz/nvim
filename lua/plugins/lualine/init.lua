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
			},
			tabline = {
				lualine_a = {
					{
						"tabs",
						max_length = math.max(20, vim.o.columns - 20),
						mode = 1,
						path = 3,
					},
				},
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				-- lualine_z = { 'overseer' },
				lualine_y = { require("plugins.lualine.overseer") },
				lualine_z = { "branch" },
			},
			winbar = {
				lualine_a = { require("plugins.lualine.file") },
			},
			inactive_winbar = {
				lualine_a = { require("plugins.lualine.file") },
			},
			sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = {},
				lualine_x = { require("plugins.lualine.coordinates") },
				lualine_y = {},
				lualine_z = {},
			},
		},
		dependencies = "MunifTanjim/nui.nvim",
		cond = not_vscode,
	},
}
