local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal
local dap = require("my.parameters").domain.dap

return {
	{
		"jbyuki/one-small-step-for-vimkind",
		keys = {
			{
				dap .. "vL",
				function()
					require("osv").launch({ port = 8086 })
				end,
				desc = "DAP OSV Launch",
			},
			{
				dap .. "vl",
				function()
					require("osv").run_this({ port = 8086 })
				end,
				desc = "DAP OSV Run This",
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
			local nvim_dap = require("dap")
			local ui = "dv"
			if ui == "dapui" then
				local dapui = require("dapui")
				nvim_dap.listeners.before.attach.dapui_config = function()
					dapui.open()
				end
				nvim_dap.listeners.before.launch.dapui_config = function()
					dapui.open()
				end
				nvim_dap.listeners.before.event_terminated.dapui_config = function()
					dapui.close()
				end
				nvim_dap.listeners.before.event_exited.dapui_config = function()
					dapui.close()
				end
			elseif ui == "dv" then
				local dv = require("dap-view")
				nvim_dap.listeners.before.attach["dap-view-config"] = function()
					dv.open()
				end
				nvim_dap.listeners.before.launch["dap-view-config"] = function()
					require("my.ui_toggle").activate("dapview", function()
						dv.open()
					end)
				end
				nvim_dap.listeners.before.event_terminated["dap-view-config"] = function()
					require("my.ui_toggle").activate("dapview", function()
						dv.open()
					end)
				end
				nvim_dap.listeners.before.event_exited["dap-view-config"] = function()
					dv.close()
				end
			end
			local packages = vim.fn.stdpath("data") .. "/mason/packages"
			nvim_dap.adapters.nlua = function(callback, config)
				callback({ type = "server", host = config.host or "127.0.0.1", port = config.port or 8086 })
			end
			nvim_dap.adapters["pwa-node"] = {
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
			require("my.tables").deep_merge(nvim_dap.configurations, require("plugins.dap.configurations"))
		end,
		keys = {
			{
				dap .. "B",
				function()
					require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
				end,
				desc = "DAP Breakpoint Condition",
			},
			{
				dap .. "b",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "DAP Toggle Breakpoint",
			},
			{
				dap .. "c",
				function()
					require("dap").continue()
				end,
				desc = "DAP Run/Continue",
			},
			{
				dap .. "a",
				function()
					require("dap").continue()
				end,
				desc = "DAP Run with Args",
			},
			{
				dap .. "C",
				function()
					require("dap").run_to_cursor()
				end,
				desc = "DAP Run to Cursor",
			},
			{
				dap .. "g",
				function()
					require("dap").goto_()
				end,
				desc = "DAP Go to Line (No Execute)",
			},
			{
				dap .. "i",
				function()
					require("dap").step_into()
				end,
				desc = "DAP Step Into",
			},
			{
				dap .. "j",
				function()
					require("dap").down()
				end,
				desc = "DAP Down",
			},
			{
				dap .. "k",
				function()
					require("dap").up()
				end,
				desc = "DAP Up",
			},
			{
				dap .. "l",
				function()
					require("dap").run_last()
				end,
				desc = "DAP Run Last",
			},
			{
				dap .. "o",
				function()
					require("dap").step_out()
				end,
				desc = "DAP Step Out",
			},
			{
				dap .. "O",
				function()
					require("dap").step_over()
				end,
				desc = "DAP Step Over",
			},
			{
				dap .. "P",
				function()
					require("dap").pause()
				end,
				desc = "DAP Pause",
			},
			{
				dap .. "r",
				function()
					require("dap").repl.toggle()
				end,
				desc = "DAP Toggle REPL",
			},
			{
				dap .. "s",
				function()
					require("dap").session()
				end,
				desc = "DAP Session",
			},
			{
				dap .. "t",
				function()
					require("dap").terminate()
				end,
				desc = "DAP Terminate",
			},
			{
				dap .. "w",
				function()
					require("dap.ui.widgets").hover()
				end,
				desc = "DAP Widgets",
			},
		},
		cond = not_vscode,
		enabled = personal,
	},
}
