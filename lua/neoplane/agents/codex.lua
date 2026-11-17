return {
	executable = "codex",
	writable_dirs = { vim.env.CODEX_HOME or "~/.codex" },
	osc_status = true,
	skill = "$%s",
	builder = function(opts)
		local cmd = { "codex" }
		if opts.resume then
			table.insert(cmd, "resume")
		end
		if opts.sandbox then
			table.insert(cmd, "--dangerously-bypass-approvals-and-sandbox")
		end
		if opts.provider then
			vim.list_extend(cmd, { "--config", "model_provider=" .. vim.json.encode(opts.provider) })
		end
		if opts.model then
			vim.list_extend(cmd, { "--model", opts.model })
		end
		if opts.effort then
			vim.list_extend(cmd, { "--config", "model_reasoning_effort=" .. opts.effort })
		end
		if opts.resume then
			table.insert(cmd, opts.title or "--last")
		end
		if opts.prompt then
			table.insert(cmd, opts.prompt)
		end
		return cmd
	end,
}
