local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal

return {
	{
		"jbyuki/one-small-step-for-vimkind",
		keys = {
			{
				"<leader>dvL",
				function()
					require("osv").launch({ port = 8086 })
				end,
				desc = "Launch OSV",
			},
			{
				"<leader>dvl",
				function()
					require("osv").run_this({ port = 8086 })
				end,
				desc = "Launch OSV",
			},
		},
		cond = not_vscode,
		enabled = personal,
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = {
			"williamboman/mason.nvim",
		},
		opts = {
			ensure_installed = { "js-debug-adapter" },
			handlers = {},
		},
		cond = not_vscode,
		enabled = personal,
	},
	{
		"theHamsta/nvim-dap-virtual-text",
		opts = {},
		cond = not_vscode,
		enabled = personal,
	},
	{
		"igorlfs/nvim-dap-view",
		---@module 'dap-view'
		---@type dapview.Config
		opts = {},
		cond = not_vscode,
		enabled = personal,
	},
	{
		"rcarriga/nvim-dap-ui",
		dependencies = {
			"nvim-neotest/nvim-nio",
			"mfussenegger/nvim-dap",
		},
		cond = not_vscode,
		enabled = personal,
	},
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"jay-babu/mason-nvim-dap.nvim",
			"theHamsta/nvim-dap-virtual-text",
			"jbyuki/one-small-step-for-vimkind",
		},
		lazy = false,
		opts = {},
		config = function()
			local dap = require("dap")
			local ui = "dv"
			if ui == "dapui" then
				local dapui = require("dapui")
				dap.listeners.before.attach.dapui_config = function()
					dapui.open()
				end
				dap.listeners.before.launch.dapui_config = function()
					dapui.open()
				end
				dap.listeners.before.event_terminated.dapui_config = function()
					dapui.close()
				end
				dap.listeners.before.event_exited.dapui_config = function()
					dapui.close()
				end
			elseif ui == "dv" then
				local dv = require("dap-view")
				dap.listeners.before.attach["dap-view-config"] = function()
					dv.open()
				end
				dap.listeners.before.launch["dap-view-config"] = function()
					dv.open()
				end
				dap.listeners.before.event_terminated["dap-view-config"] = function()
					dv.close()
				end
				dap.listeners.before.event_exited["dap-view-config"] = function()
					dv.close()
				end
			end
			local packages = vim.fn.stdpath("data") .. "/mason/packages"
			dap.adapters.nlua = function(callback, config)
				callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
			end
			dap.adapters["pwa-node"] = {
				type = "server",
				host = "localhost",
				port = "${port}",
				executable = {
					command = "node",
					args = {
						packages .. "/js-debug-adapter/js-debug/src/dapDebugServer.js",
						"${port}",
					},
				},
			}
			require("my.tables").deep_merge(dap.configurations, require("plugins.dap.configurations"))
		end,
		keys = {
			{
				"<leader>dB",
				function()
					require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
				end,
				desc = "Breakpoint Condition",
			},
			{
				"<leader>db",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Toggle Breakpoint",
			},
			{
				"<leader>dc",
				function()
					require("dap").continue()
				end,
				desc = "Run/Continue",
			},
			{
				"<leader>da",
				function()
					require("dap").continue()
				end,
				desc = "Run with Args",
			},
			{
				"<leader>dC",
				function()
					require("dap").run_to_cursor()
				end,
				desc = "Run to Cursor",
			},
			{
				"<leader>dg",
				function()
					require("dap").goto_()
				end,
				desc = "Go to Line (No Execute)",
			},
			{
				"<leader>di",
				function()
					require("dap").step_into()
				end,
				desc = "Step Into",
			},
			{
				"<leader>dj",
				function()
					require("dap").down()
				end,
				desc = "Down",
			},
			{
				"<leader>dk",
				function()
					require("dap").up()
				end,
				desc = "Up",
			},
			{
				"<leader>dl",
				function()
					require("dap").run_last()
				end,
				desc = "Run Last",
			},
			{
				"<leader>do",
				function()
					require("dap").step_out()
				end,
				desc = "Step Out",
			},
			{
				"<leader>dO",
				function()
					require("dap").step_over()
				end,
				desc = "Step Over",
			},
			{
				"<leader>dP",
				function()
					require("dap").pause()
				end,
				desc = "Pause",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.toggle()
				end,
				desc = "Toggle REPL",
			},
			{
				"<leader>ds",
				function()
					require("dap").session()
				end,
				desc = "Session",
			},
			{
				"<leader>dt",
				function()
					require("dap").terminate()
				end,
				desc = "Terminate",
			},
			{
				"<leader>dw",
				function()
					require("dap.ui.widgets").hover()
				end,
				desc = "Widgets",
			},
		},
		cond = not_vscode,
		enabled = personal,
	},
}
