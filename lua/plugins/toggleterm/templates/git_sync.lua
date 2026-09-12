local function git_output(args, cwd)
	local result = vim.system(args, { cwd = cwd, text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	return vim.trim(result.stdout)
end

local function is_enabled(cwd)
	local branch = git_output({ "git", "branch", "--show-current" }, cwd)
	if not branch or branch == "" then
		return false
	end

	local enabled = git_output({ "git", "config", "--get", "--bool", "branch." .. branch .. ".sync" }, cwd)
	if enabled == nil then
		enabled = git_output({ "git", "config", "--get", "--bool", "git-sync.syncEnabled" }, cwd)
	end
	return enabled == "true"
end

return {
	generator = function(opts)
		if not is_enabled(opts.dir) then
			return nil
		end

		return {
			{
				name = "git-sync",
				builder = function()
					return { cmd = "git-sync", cwd = opts.dir }
				end,
			},
		}
	end,
}
