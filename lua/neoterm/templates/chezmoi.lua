local async = require("neoterm.helpers.term_templates")

local function target_path(source_path, file, callback)
	if file == "" or not vim.startswith(vim.fs.normalize(file), vim.fs.normalize(source_path) .. "/") then
		return callback(nil)
	end

	vim.system(
		{ "chezmoi", "target-path", file },
		{ cwd = source_path, text = true },
		vim.schedule_wrap(function(result)
			if result.code ~= 0 then
				return callback(nil)
			end

			local target = vim.trim(result.stdout or "")
			callback(target ~= "" and target or nil)
		end)
	)
end

return {
	generator = function(opts, callback)
		async.executable("chezmoi", function(installed)
			if not installed then
				return callback(nil)
			end

			vim.system(
				{ "chezmoi", "source-path" },
				{ text = true },
				vim.schedule_wrap(function(result)
					if result.code ~= 0 then
						return callback(nil)
					end
					local source_path = vim.trim(result.stdout or "")
					if opts.cwd ~= source_path then
						return callback(nil)
					end

					local definitions = {
						{
							name = "chezmoi apply",
							cmd = { "chezmoi", "apply" },
							cwd = source_path,
							close_on_exit = false,
						},
					}

					target_path(source_path, opts.file, function(target)
						if target then
							for _, value in ipairs({ "add", "diff", "destroy" }) do
								local command = value
								table.insert(definitions, {
									name = "chezmoi " .. command,
									cmd = { "chezmoi", command, target },
									cwd = source_path,
									close_on_exit = false,
								})
							end
						end
						callback(definitions)
					end)
				end)
			)
		end)
	end,
}
