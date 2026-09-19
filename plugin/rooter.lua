if not require("my.conds").not_vscode() then
	return
end

local group = vim.api.nvim_create_augroup("MyRooter", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter" }, {
	group = group,
	nested = true,
	callback = function()
		require("neoterm.rooter").on_buf_enter()
	end,
})
