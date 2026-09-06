if not require("my.conds").not_vscode() then
	return
end

local logical_path = require("my.logical_path")

local function normalize(path)
	local normalized = vim.fs.normalize(path)
	return normalized ~= "/" and normalized:gsub("/+$", "") or normalized
end

local group = vim.api.nvim_create_augroup("MyRooter", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter" }, {
	group = group,
	nested = true,
	callback = function()
		if vim.bo.buftype ~= "" then
			return
		end

		local saved = logical_path.capture(0)
		local cwd = normalize(vim.fn.getcwd())
		local root
		if saved ~= nil and cwd == saved then
			root = saved
		else
			root = vim.fs.root(0, require("my.parameters").rooter_patterns)
		end
		if root then
			vim.api.nvim_set_current_dir(root)
			require("plugins.toggleterm.terms").on_dir()
		end
	end,
})
