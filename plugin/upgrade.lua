local function system_upgrade()
	require("lazy").sync({ wait = true })
	vim.cmd("TSUpdateSync")
	local registry = require("mason-registry")
	registry.refresh()
	local packages = registry.get_installed_package_names()
	if #packages > 0 then
		vim.cmd("MasonUpdate")
		vim.cmd("MasonInstall " .. table.concat(packages, " "))
	end
end

-- Create a user command for manual use inside Nvim
vim.api.nvim_create_user_command("SystemUpgrade", system_upgrade, {})
