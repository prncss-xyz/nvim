return {
	generator = function(opts)
		if vim.fn.executable("chezmoi") == 0 then
			return nil
		end

		local source_path = vim.trim(vim.fn.system("chezmoi source-path"))
		if opts.dir ~= source_path then
			return nil
		end

		return {
			{
				name = "chezmoi",
				builder = function()
					return { cmd = { "chezmoi", "apply" }, cwd = source_path }
				end,
			},
		}
	end,
}
