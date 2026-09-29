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
		if opts.resume and not opts.title then
			table.insert(cmd, "--continue")
		elseif opts.resume then
			local directory = (vim.env.PI_CODING_AGENT_DIR or vim.fn.expand("~/.pi/agent"))
				.. "/sessions/--" .. vim.fs.normalize(opts.cwd or vim.fn.getcwd()):sub(2):gsub("/", "-") .. "--"
			local matches = vim.fn.glob(directory .. "/*.jsonl", false, true)
			table.sort(matches, function(a, b) return a > b end)
			local session
			for _, path in ipairs(matches) do
				local name
				for line in io.lines(path) do
					local ok, entry = pcall(vim.json.decode, line)
					if ok and entry.type == "session_info" and entry.name then
						name = entry.name
					end
				end
				if name == opts.title then
					session = path
					break
				end
			end
			assert(session, "No pi session with title: " .. opts.title)
			vim.list_extend(cmd, { "--session", session })
		elseif opts.title then
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
