local group = vim.api.nvim_create_augroup("ToggleTermFocus", { clear = true })
vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
	group = group,
	callback = function()
		if vim.bo.buftype == "terminal" then
			vim.defer_fn(function()
				if vim.api.nvim_buf_is_valid(0) and vim.bo.buftype == "terminal" then
					vim.cmd("startinsert")
				end
			end, 75)
		end
	end,
})
