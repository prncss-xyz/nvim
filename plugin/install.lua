local function system_upgrade()
	vim.cmd(
		"MasonInstall json-lsp prettierd ltex-ls lua-language-server marksman stylua vtsls yaml-language-server"
	)
end

-- Create a user command for manual use inside Nvim
vim.api.nvim_create_user_command("SystemInstall", system_upgrade, {})
