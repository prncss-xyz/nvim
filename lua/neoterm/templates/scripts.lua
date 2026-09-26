return function(opts, callback)
	local cwd = vim.fs.abspath(opts.cwd or opts.dir)
	local scripts = vim.fs.joinpath(cwd, "scripts")
	local definitions = {}
	vim.uv.fs_scandir(
		scripts,
		vim.schedule_wrap(function(err, handle)
			if not err then
				while true do
					local name, kind = vim.uv.fs_scandir_next(handle)
					if not name then
						break
					end
					local path = vim.fs.joinpath(scripts, name)
					if kind == "file" and vim.fn.executable(path) == 1 then
						table.insert(definitions, {
							name = "scripts/" .. name,
							cmd = { path },
							cwd = cwd,
						})
					end
				end
			end
			table.sort(definitions, function(a, b)
				return a.name < b.name
			end)
			callback(definitions)
		end)
	)
end
