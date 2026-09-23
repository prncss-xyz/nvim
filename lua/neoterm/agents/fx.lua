return {
	writable_paths = { "~/.fx" },
	screen_manifest = {
		default_status = "idle",
		rules = {
			{
				id = "approval_prompt",
				status = "blocked",
				priority = 900,
				region = "bottom_non_empty_lines(20)",
				visible_blocker = true,
				contains = { "Allow once", "Deny" },
			},
			{
				id = "confirmation_prompt",
				status = "blocked",
				priority = 900,
				region = "bottom_non_empty_lines(20)",
				visible_blocker = true,
				contains = { "1. Confirm", "2. Cancel" },
			},
			{
				id = "turn_activity",
				status = "working",
				priority = 500,
				region = "bottom_non_empty_lines(8)",
				visible_working = true,
				line_regex = {
					[[^\s*• \(Thinking\|Generating\|Running\|Preparing compaction\|Compacting\|Stopping compaction\)\( (\|$\)]],
				},
			},
		},
	},
	builder = function(opts)
		local cmd = { "fx" }
		if opts.prompt then
			vim.list_extend(cmd, { "ask", opts.prompt })
		end
		return cmd
	end,
}

