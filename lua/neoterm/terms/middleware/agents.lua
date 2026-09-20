local M = {}

local writable_paths = {
	pi = { vim.env.PI_CODING_AGENT_DIR or "~/.pi/agent" },
	agy = {
		"~/.gemini",
		"~/.antigravity",
		"~/.antigravitycli",
		"~/.cache/antigravity",
	},
	claude = {
		vim.env.CLAUDE_CONFIG_DIR or "~/.claude",
		"~/.claude.json",
		"~/.claude.json.lock",
	},
}

local screen_manifests = {
	pi = {
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
			id = "running_status_bar",
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
	claude = {
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
}

M.builders = {
	pi = function(opts)
		local cmd = { "p" }
		if opts.title then
			vim.list_extend(cmd, { "--name", opts.title })
		end
		if opts.prompt then
			table.insert(cmd, opts.prompt)
		end
		return cmd
	end,
	claude = function(opts)
		local cmd = { "claude" }
		if opts.sandbox then
			table.insert(cmd, "--dangerously-skip-permissions")
		end
		if opts.title then
			vim.list_extend(cmd, { "--name", opts.title })
		end
		if opts.prompt then
			table.insert(cmd, opts.prompt)
		end
		return cmd
	end,
	agy = function(opts)
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

function M.agent(opts)
	local builder = assert(M.builders[opts.agent], "Unknown coding agent: " .. opts.agent)
	local resolved = vim.tbl_extend("force", { sandbox = require("my.conds").personal("bwrap") }, opts)
	return vim.tbl_extend("force", {
		cmd = builder(resolved),
		auto_scroll = false,
		writable_paths = writable_paths[opts.agent],
		exit_policy = "keep",
		tag = "agent",
		screen_manifest = screen_manifests[opts.agent],
	}, resolved)
end

return M
