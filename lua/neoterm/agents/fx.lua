return {
	writable_dirs = { "~/.fx" },
	osc_status = true,
	builder = function(opts)
		local cmd = { "fx" }
		if opts.resume then
			vim.list_extend(cmd, { "--resume", opts.title or "last" })
		end
		if opts.provider then
			vim.list_extend(cmd, { "--provider", opts.provider })
		end
		if opts.model then
			vim.list_extend(cmd, { "--model", opts.model })
		end
		if opts.effort then
			vim.list_extend(cmd, { "--effort", opts.effort })
		end
		if opts.prompt then
			vim.list_extend(cmd, { "ask", opts.prompt })
		end
		return cmd
	end,
}
