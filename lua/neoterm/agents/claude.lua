return {
	writable_dirs = {
		vim.env.CLAUDE_CONFIG_DIR or "~/.claude",
	},
	writable_files = {
		"~/.claude.json",
		"~/.claude.json.lock",
	},
	osc_status = true,
	builder = function(opts)
		local cmd = { "claude" }
		if opts.sandbox then
			table.insert(cmd, "--dangerously-skip-permissions")
		end
		if opts.resume then
			if opts.title then
				vim.list_extend(cmd, { "--resume", opts.title })
			else
				table.insert(cmd, "--continue")
			end
		elseif opts.title then
			vim.list_extend(cmd, { "--name", opts.title })
		end
		if opts.model then
			vim.list_extend(cmd, { "--model", opts.model })
		end
		if opts.effort then
			vim.list_extend(cmd, { "--effort", opts.effort })
		end
		if opts.prompt then
			table.insert(cmd, opts.prompt)
		end
		return cmd
	end,
}
