if not require("my.conds").not_vscode() then
	return
end

local group = vim.api.nvim_create_augroup("Neoterm", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter" }, {
	group = group,
	nested = true,
	callback = function()
		require("neoterm.rooter").on_buf_enter()
	end,
})

vim.api.nvim_create_autocmd("WinEnter", {
	group = group,
	callback = function()
		require("neoterm.helpers.win_history").on_win_enter()
	end,
})
