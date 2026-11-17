local function toggle_index_file()
	local source = vim.api.nvim_buf_get_name(0)
	if source == "" then
		vim.notify("Current buffer has no file", vim.log.levels.WARN)
		return
	end

	if vim.bo.modified then
		vim.cmd.write()
	end

	local directory = vim.fs.dirname(source)
	local filename = vim.fs.basename(source)
	local name, extension = filename:match("^(.*)(%.[^.]+)$")
	if not name then
		vim.notify("Current file has no extension", vim.log.levels.WARN)
		return
	end

	local target
	local remove_directory = false
	local create_directory = false
	local branch, branch_name = name:match("^([^.]+)%.(.+)$")
	if extension == ".lua" and name == "init" then
		for entry in vim.fs.dir(directory) do
			if entry ~= filename then
				vim.notify("Directory contains other files: " .. directory, vim.log.levels.WARN)
				return
			end
		end

		target = vim.fs.joinpath(vim.fs.dirname(directory), vim.fs.basename(directory) .. extension)
		remove_directory = true
	elseif extension == ".lua" and not branch then
		target = vim.fs.joinpath(directory, name, "init" .. extension)
		create_directory = true
	elseif branch then
		target = vim.fs.joinpath(directory, branch, branch_name .. extension)
	else
		for entry in vim.fs.dir(directory) do
			if entry ~= filename then
				vim.notify("Directory contains other files: " .. directory, vim.log.levels.WARN)
				return
			end
		end

		local flattened_name = vim.fs.basename(directory)
		if name ~= "index" then
			flattened_name = flattened_name .. "." .. name
		end
		target = vim.fs.joinpath(vim.fs.dirname(directory), flattened_name .. extension)
		remove_directory = true
	end

	if vim.uv.fs_stat(target) then
		vim.notify("Target already exists: " .. target, vim.log.levels.WARN)
		return
	end

	local target_directory = vim.fs.dirname(target)
	local directory_created = create_directory and not vim.uv.fs_stat(target_directory)
	if directory_created and vim.fn.mkdir(target_directory, "p") == 0 then
		vim.notify("Failed to create directory: " .. target_directory, vim.log.levels.ERROR)
		return
	end

	Snacks.rename.rename_file({
		from = source,
		to = target,
		on_rename = function(_, _, ok)
			if remove_directory and ok then
				local removed, error = vim.uv.fs_rmdir(directory)
				if not removed then
					vim.notify("Failed to remove directory: " .. error, vim.log.levels.ERROR)
				end
			elseif directory_created and not ok then
				vim.uv.fs_rmdir(target_directory)
			end
		end,
	})
end

return toggle_index_file
