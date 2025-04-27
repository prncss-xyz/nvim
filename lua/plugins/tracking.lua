local personal = require("my.conds").personal

return {
	{
		"ptdewey/pendulum-nvim",
		name = "pendulum",
		event = "VeryLazy",
		config = function()
			require("pendulum").setup({
				log_file = vim.fn.expand("$HOME/Personal/pendulum/$HOST.csv"),
			})
		end,
		cmd = { "Pendulum", "PendulumRebuild" },
		enabled = personal,
	},
}
