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
				lualine_z = { { "terminal_changed", color = "DiagnosticWarn" } },
			},
		},
		config = function(_, opts)
			local lualine = require("lualine")
			lualine.setup(opts)
			vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
				group = vim.api.nvim_create_augroup("LualineWindowRefresh", { clear = true }),
				callback = function()
					-- New buffer/window views inherit lualine's blank global statusline.
					-- Populate it before a redraw, rather than waiting for the refresh queue.
					lualine.refresh({ place = { "statusline" }, force = true })
				end,
			})
		end,
		cond = not_vscode,
	},
}
