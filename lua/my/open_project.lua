local M = {}

function M.open_project(cwd)
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

return M
