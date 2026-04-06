if not require("my.conds").not_vscode() then
	return
end
local group = vim.api.nvim_create_augroup("MyWatch", { clear = true })

vim.api.nvim_create_autocmd({ "User" }, {
	group = group,
	pattern = "VeryLazy",
	callback = require("my.watch").enable,
})
