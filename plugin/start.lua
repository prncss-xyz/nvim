if not require("my.conds").not_vscode() then
	return
end

local group = vim.api.nvim_create_augroup("My", {})

local function open_project(cwd)
	if cwd == vim.fn.getenv("HOME") then
		Snacks.dashboard()
		return
	end
	if not vim.endswith(cwd, "/") then
		cwd = cwd .. "/"
	end
	for _, file in ipairs(vim.v.oldfiles) do
		if vim.startswith(file, cwd) and vim.fn.filereadable(file) == 1 then
			vim.cmd.edit(file)
			return
		end
	end
	Snacks.picker.smart({
		cwd = cwd,
	})
end

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
			open_project(cwd)
		end)
	end,
})
