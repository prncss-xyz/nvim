local not_vscode = require("my.conds").not_vscode
local tests = require("my.parameters").domain.tests
local reverse = require("my.parameters").reverse

return {
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"nvim-lua/plenary.nvim",
			{ "antoinemadec/FixCursorHold.nvim", commit = "1900f89" },
			"nvim-treesitter/nvim-treesitter",
			{ "nvim-neotest/neotest-plenary", commit = "3523adc" },
			{ "marilari88/neotest-vitest", commit = "f01addc6f07b79ef1be5f4297eafbee9e0959018" },
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-plenary"),
					require("neotest-vitest"),
				},
				diagnostics = {
					enable = true,
					virtual_text = true,
				},
			})
		end,
		opts = {
			adapters = {},
		},
		keys = {
			{
				tests .. "d",
				function()
					require("neotest").run.run({ vim.fn.expand("%"), strategy = "dap" })
				end,
				desc = "Neotest Debug File (DAP)",
			},
			{
				tests .. "t",
				function()
					require("neotest").run.run(vim.fn.expand("%"))
				end,
				desc = "Neotest Run File",
			},
			{
				tests .. reverse("t"),
				function()
					require("neotest").run.run(vim.uv.cwd())
				end,
				desc = "Neotest Run All Test Files",
			},
			{
				tests .. "l",
				function()
					require("neotest").run.run_last()
				end,
				desc = "Neotest Run Last",
			},
			{
				tests .. "s",
				function()
					require("neotest").summary.toggle()
				end,
				desc = "Neotest Toggle Summary",
			},
			{
				tests .. "o",
				function()
					require("neotest").output.open({ enter = true, auto_close = true })
				end,
				desc = "Neotest Show Output",
			},
			{
				tests .. "r",
				function()
					require("neotest").output_panel.toggle()
				end,
				desc = "Neotest Toggle Output Panel",
			},
			{
				tests .. "x",
				function()
					require("neotest").run.stop()
				end,
				desc = "Neotest Stop",
			},
			{
				tests .. "w",
				"<cmd>lua require('neotest').run.run({ vitestCommand = 'vitest --watch' })<cr>",
				desc = "Neotest Watch",
			},
		},

		cond = not_vscode,
	},
}
