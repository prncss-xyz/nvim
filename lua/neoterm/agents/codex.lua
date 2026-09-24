return {
	executable = "codex",
	writable_paths = { vim.env.CODEX_HOME or "~/.codex" },
	screen_manifest = {
		default_status = "idle",
		rules = {
			{
				id = "osc_title_blocked",
				status = "blocked",
				priority = 1100,
				region = "osc_title",
				visible_blocker = true,
				contains = { "Action Required" },
			},
			{
				id = "osc_title_working",
				status = "working",
				priority = 1050,
				region = "osc_title",
				visible_working = true,
				regex = { "[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]" },
			},
			{
				id = "transcript_viewer",
				status = "unknown",
				priority = 1000,
				region = "after_last_prompt_marker",
				skip_state_update = true,
				contains = { "↑/↓ to scroll", "pgup/pgdn to", "home/end to jump", "q to quit" },
				any = {
					{ contains = { "esc to edit prev" } },
					{ contains = { "esc/← to edit prev" } },
				},
			},
			{
				id = "trust_directory",
				status = "blocked",
				priority = 950,
				region = "top_non_empty_lines(20)",
				visible_blocker = true,
				contains = { "Do you trust the contents of this directory?" },
				line_regex = { [[^> You are in ]] },
			},
			{
				id = "startup_update",
				status = "blocked",
				priority = 950,
				region = "bottom_non_empty_lines(20)",
				visible_blocker = true,
				contains = { "Update available!", "Update now", "Skip until next version", "Press enter to continue" },
			},
			{
				id = "live_strong_blocker",
				status = "blocked",
				priority = 900,
				region = "after_last_prompt_marker",
				visible_blocker = true,
				any = {
					{ contains = { "press enter to confirm or esc to cancel" } },
					{ contains = { "enter to submit answer" } },
					{ contains = { "enter to submit all" } },
					{ contains = { "allow command?" } },
				},
			},
			{
				id = "weak_blocker",
				status = "blocked",
				priority = 600,
				region = "whole_recent_without_current_prompt_marker",
				any = {
					{ contains = { "[y/n]" } },
					{ contains = { "yes (y)" } },
					{ contains = { "do you want to" }, any = { { contains = { "yes" } }, { contains = { "❯" } } } },
					{
						contains = { "would you like to" },
						any = { { contains = { "yes" } }, { contains = { "❯" } } },
					},
				},
			},
			{
				id = "screen_working_fallback",
				status = "working",
				priority = 500,
				region = "before_current_prompt_marker",
				visible_working = true,
				any = { { contains = { " to interrupt)" } }, { contains = { "s)" } } },
				line_regex = { [[ ([0-9]\+[hm] )*[0-9]\+s]] },
				["not"] = { { line_regex = { [[^Reconnect failed — check the endpoint, then relaunch (]] } } },
			},
			{
				id = "osc_title_idle",
				status = "idle",
				priority = 100,
				region = "osc_title",
				visible_idle = true,
				regex = { [[\S]] },
				["not"] = {
					{ regex = { "[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]" } },
					{ contains = { "Action Required" } },
				},
			},
		},
	},
	builder = function(opts)
		local cmd = { "codex" }
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
		if opts.prompt then
			table.insert(cmd, opts.prompt)
		end
		return cmd
	end,
}
