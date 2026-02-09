local not_vscode = require("my.conds").not_vscode

local function starship()
	local ok, result = pcall(function()
		local handle = io.popen("starship prompt --status=0 --jobs=0 2>/dev/null")
		if not handle then
			return ""
		end
		local output = handle:read("*a")
		handle:close()
		if not output then
			return ""
		end
		-- Strip all ANSI escape sequences
		output = output:gsub("\27%[[^a-zA-Z]*[a-zA-Z]", "")
		-- Join non-empty lines and trim
		local parts = {}
		for line in output:gmatch("[^\n]+") do
			local trimmed = line:gsub("^%s*(.-)%s*$", "%1")
			if trimmed ~= "" then
				parts[#parts + 1] = trimmed
			end
		end
		return table.concat(parts, " ")
	end)
	return ok and result or ""
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
