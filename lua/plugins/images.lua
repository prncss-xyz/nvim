local tui = require("my.conds").tui

return {
	{
		"3rd/image.nvim",
		opts = {},
		event = "VeryLazy",
		enabled = tui,
	},
}
