local function system_upgrade()
	vim.cmd(
		"MasonInstall ltex-ls lua-language-server stylua"
	)
end

-- Create a user command for manual use inside Nvim
vim.api.nvim_create_user_command("SystemInstall", system_upgrade, {})
