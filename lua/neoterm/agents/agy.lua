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
		if opts.prompt then
			vim.list_extend(cmd, { "--prompt-interactive", opts.prompt })
		end
		return cmd
	end,
}
