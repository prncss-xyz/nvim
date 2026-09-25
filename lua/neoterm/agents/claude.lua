return {
	writable_dirs = {
		vim.env.CLAUDE_CONFIG_DIR or "~/.claude",
	},
	writable_files = {
		"~/.claude.json",
		"~/.claude.json.lock",
	},
	screen_manifest = {
		default_status = "idle",
		rules = {
			{
				id = "osc_title_working",
				status = "working",
				priority = 1100,
				region = "osc_title",
				visible_working = true,
				regex = { "^[⠀-⣿◐-◓] " },
			},
			{
				id = "permission_prompt",
				status = "blocked",
				priority = 900,
				region = "after_last_horizontal_rule",
				any = {
					{ contains = { "do you want to proceed?" } },
					{ contains = { "waiting for permission" } },
					{ contains = { "tab to amend" } },
					{ contains = { "esc to cancel", "enter to select" } },
				},
			},
			{
				id = "working_interrupt_hint",
				status = "working",
				priority = 500,
				region = "bottom_non_empty_lines(5)",
				any = {
					{ contains = { "esc to interrupt" } },
					{ contains = { "ctrl+c to interrupt" } },
				},
			},
			{
				id = "osc_title_idle",
				status = "idle",
				priority = 250,
				region = "osc_title",
				visible_idle = true,
				regex = { "^✳ " },
			},
			{
				id = "osc_progress_idle",
				status = "idle",
				priority = 250,
				region = "osc_progress",
				regex = { "^4;0" },
			},
			{
				id = "prompt",
				status = "idle",
				priority = 100,
				region = "prompt_box_body",
				line_regex = { [[^\s*❯]] },
			},
		},
	},
	builder = function(opts)
		local cmd = { "claude" }
		if opts.sandbox then
			table.insert(cmd, "--dangerously-skip-permissions")
		end
		if opts.title then
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
