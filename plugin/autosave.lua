if not require("my.conds").not_vscode() then
	return
end
local group = vim.api.nvim_create_augroup("MyAutoSave", { clear = true })

vim.api.nvim_create_autocmd({ "TabLeave", "FocusLost", "BufLeave", "VimLeavePre" }, {
	pattern = "*?", -- do not match buffers with no name
	group = group,
	callback = function()
		if not vim.api.nvim_buf_is_valid(0) then
			return
		end
		if vim.bo.buftype ~= "" then
			return
		end
		if not vim.bo.modifiable then
			return
		end
		if not vim.bo.modified then
			return
		end
		local fname = vim.api.nvim_buf_get_name(0)
		if vim.fn.isdirectory(fname) == 1 then
			return
		end
		if require("khutulun.utils.files").is_file(fname) then
			vim.cmd("silent update")
		else
			vim.cmd("silent :w!")
		end
	end,
})
