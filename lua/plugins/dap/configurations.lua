local M = {}
-- https://github.com/harrisoncramer/nvim/tree/main/lua/plugins/dap

local jsOrTs = {
	{
		type = "pwa-node",
		request = "launch",
		name = "Launch file",
		program = "${file}",
		cwd = "${workspaceFolder}",
	},
	{
		name = "Vitest Debug",
		type = "pwa-node",
		request = "launch",
		cwd = vim.fn.getcwd(),
		program = "${workspaceFolder}/node_modules/vitest/vitest.mjs",
		args = { "run", "${file}" },
		autoAttachChildProcesses = true,
		smartStep = true,
		console = "integratedTerminal",
		skipFiles = { "<node_internals>/**", "node_modules/**" },
	},
}

M.javascript = jsOrTs
M.typescript = jsOrTs

M.lua = {
	{
		type = "nlua",
		request = "attach",
		name = "Attach to running Neovim instance",
	},
}

return M
