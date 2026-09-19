local function git_output(args, cwd, callback)
	vim.system(
		args,
		{ cwd = cwd, text = true },
		vim.schedule_wrap(function(result)
			if result.code ~= 0 then
				return callback(nil)
			end
			callback(vim.trim(result.stdout))
		end)
	)
end

local function is_enabled(cwd, callback)
	git_output({ "git", "branch", "--show-current" }, cwd, function(branch)
		if not branch or branch == "" then
			return callback(false)
		end

		git_output({ "git", "config", "--get", "--bool", "branch." .. branch .. ".sync" }, cwd, function(enabled)
			if enabled ~= nil then
				return callback(enabled == "true")
			end
			git_output({ "git", "config", "--get", "--bool", "git-sync.syncEnabled" }, cwd, function(fallback)
				callback(fallback == "true")
			end)
		end)
	end)
end

return {
	generator = function(opts, callback)
		is_enabled(opts.cwd, function(enabled)
			if not enabled then
				return callback(nil)
			end

			callback({
				{
					name = "git-sync",
					builder = function()
						return { cmd = "git-sync", cwd = opts.cwd }
					end,
				},
			})
		end)
	end,
}
