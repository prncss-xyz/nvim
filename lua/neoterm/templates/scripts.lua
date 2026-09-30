return function(opts, callback)
	local cwd = vim.fs.abspath(opts.cwd or opts.dir)
	local scripts = vim.fs.joinpath(cwd, "scripts")
	local definitions = {}
	local pending = 0
	local function scan(dir, relative)
		pending = pending + 1
		vim.uv.fs_scandir(dir, vim.schedule_wrap(function(err, handle)
			if not err then
				while true do
					local name, kind = vim.uv.fs_scandir_next(handle)
					if not name then
						break
					end
					if name:sub(1, 1) ~= "." and name ~= "node_modules" then
						local path = vim.fs.joinpath(dir, name)
						local script_name = relative == "" and name or relative .. "/" .. name
						if kind == "directory" then
							scan(path, script_name)
						elseif kind == "file" and vim.fn.executable(path) == 1 then
							table.insert(definitions, {
								name = "scripts/" .. script_name,
								cmd = { path },
								cwd = cwd,
								exit_policy = "keep",
							})
							end
					end
				end
			end
			pending = pending - 1
			if pending ~= 0 then
				return
			end
			table.sort(definitions, function(a, b)
				return a.name < b.name
			end)
			callback(definitions)
		end))
	end
	scan(scripts, "")
end
