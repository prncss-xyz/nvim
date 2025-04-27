local group = vim.api.nvim_create_augroup("MyLists", {})

-- Adds '-' on next line when editing a list
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown" },
	group = group,
	callback = function()
		vim.cmd([[
      setlocal formatoptions+=r
      setlocal comments-=fb:- comments+=:-
    ]])
	end,
})
