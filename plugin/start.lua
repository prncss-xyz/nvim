if not require("my.conds").not_vscode() then
	return
end

local group = vim.api.nvim_create_augroup("My", {})

vim.api.nvim_create_autocmd("VimEnter", {
	pattern = "*",
	group = group,
	callback = function()
		local args = vim.fn.argv()
		local cwd
		if #args > 1 then
			return
		elseif #args == 1 then
			local arg = args[1]
			if vim.fn.isdirectory(arg) == 1 then
				cwd = vim.fn.fnamemodify(arg, ":p")
			else
				return
			end
		else
			cwd = vim.fn.getcwd()
		end
		vim.schedule(function()
			require("plugins.snacks.projects").open_project(cwd)
		end)
	end,
})
