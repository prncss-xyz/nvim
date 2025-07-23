return {
	{
		"3rd/image.nvim",
		opts = {},
		event = "VeryLazy",
		enabled = require("my.conds").tui,
		-- cond = require("my.conds").personal,
		cond = false,
	},
}
