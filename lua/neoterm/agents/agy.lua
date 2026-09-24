return {
	writable_paths = {
		"~/.gemini",
		"~/.antigravity",
		"~/.antigravitycli",
		"~/.cache/antigravity",
	},
	builder = function(opts)
		local cmd = { "agy" }
		if opts.sandbox then
			table.insert(cmd, "--dangerously-skip-permissions")
		end
		if opts.model then
			vim.list_extend(cmd, { "--model", opts.model })
		end
		if opts.effort then
			vim.list_extend(cmd, { "--effort", opts.effort })
		end
		if opts.prompt then
			vim.list_extend(cmd, { "--prompt-interactive", opts.prompt })
		end
		return cmd
	end,
}
