return {
	writable_dirs = { vim.env.PI_CODING_AGENT_DIR or "~/.pi/agent" },
	screen_manifest = {
		default_status = "idle",
		rules = {
			{
				id = "working_literal",
				status = "working",
				priority = 100,
				region = "whole_recent",
				visible_working = true,
				contains = { "Working..." },
			},
			{
				id = "working_spinner",
				status = "working",
				priority = 100,
				region = "bottom_non_empty_lines(12)",
				visible_working = true,
				line_regex = { [[^\s*[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] Working\s*$]] },
			},
			{
				id = "working_border",
				status = "working",
				priority = 100,
				region = "bottom_non_empty_lines(12)",
				visible_working = true,
				line_regex = { [[^── [⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏] Working ─\+$]] },
			},
		},
	},
	builder = function(opts)
		local cmd = { "pi" }
		if opts.title then
			vim.list_extend(cmd, { "--name", opts.title })
		end
		if opts.provider then
			vim.list_extend(cmd, { "--provider", opts.provider })
		end
		if opts.model then
			vim.list_extend(cmd, { "--model", opts.model })
		end
		if opts.effort then
			vim.list_extend(cmd, { "--thinking", opts.effort })
		end
		if opts.prompt then
			table.insert(cmd, opts.prompt)
		end
		return cmd
	end,
}
