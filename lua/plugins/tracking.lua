local personal = require("my.conds").personal
local hostname = "crotte"

return {
	{
		"ptdewey/pendulum-nvim",
		name = "pendulum",
		event = "VeryLazy",
		config = function()
			require("pendulum").setup({
				-- log_file = vim.fn.expand("$HOME/Personal/pendulum/$HOSTNAME.csv"),
				log_file = string.format("%s/Personal/pendulum/%s.csv", vim.env.HOME, hostname),
			})
		end,
		cmd = { "Pendulum", "PendulumRebuild" },
		enabled = personal,
	},
}
