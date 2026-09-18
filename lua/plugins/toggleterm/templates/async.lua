local M = {}

local function scheduled(callback)
	return vim.schedule_wrap(callback)
end

function M.executable(command, callback)
	vim.system(
		{ "sh", "-c", 'command -v -- "$1" >/dev/null 2>&1', "sh", command },
		{},
		scheduled(function(result)
			callback(result.code == 0)
		end)
	)
end

function M.stat(path, callback)
	vim.uv.fs_stat(
		path,
		scheduled(function(_, stat)
			callback(stat)
		end)
	)
end

function M.read_file(path, callback)
	vim.uv.fs_open(
		path,
		"r",
		438,
		scheduled(function(open_err, fd)
			if open_err then
				return callback(nil)
			end
			vim.uv.fs_fstat(
				fd,
				scheduled(function(stat_err, stat)
					if stat_err then
						vim.uv.fs_close(fd)
						return callback(nil)
					end
					vim.uv.fs_read(
						fd,
						stat.size,
						0,
						scheduled(function(read_err, content)
							vim.uv.fs_close(fd)
							callback(read_err and nil or content)
						end)
					)
				end)
			)
		end)
	)
end

function M.read_json(path, callback)
	M.read_file(path, function(content)
		if content == nil then
			return callback(nil)
		end
		local ok, data = pcall(vim.json.decode, content)
		callback(ok and data or nil)
	end)
end

function M.find_up(name, path, max_parents, callback)
	local results = {}
	local dir = vim.fs.abspath(path)
	local remaining = max_parents + 1

	local function visit()
		local candidate = vim.fs.joinpath(dir, name)
		M.stat(candidate, function(stat)
			if stat and stat.type == "file" then
				table.insert(results, candidate)
			end
			remaining = remaining - 1
			local parent = vim.fs.dirname(dir)
			if remaining == 0 or parent == dir then
				return callback(results)
			end
			dir = parent
			visit()
		end)
	end

	visit()
end

function M.find_up_match(path, predicate, callback)
	local dir = vim.fs.abspath(path)
	local function visit()
		vim.uv.fs_scandir(
			dir,
			scheduled(function(err, handle)
				if not err then
					while true do
						local name, kind = vim.uv.fs_scandir_next(handle)
						if not name then
							break
						end
						if predicate(name, kind) then
							return callback(vim.fs.joinpath(dir, name))
						end
					end
				end
				local parent = vim.fs.dirname(dir)
				if parent == dir then
					return callback(nil)
				end
				dir = parent
				visit()
			end)
		)
	end
	visit()
end

function M.walk_files(root, max_depth, opts, callback)
	local files = {}
	local pending = 1

	local function complete()
		pending = pending - 1
		if pending == 0 then
			table.sort(files)
			callback(files)
		end
	end

	local function scan(dir, depth)
		vim.uv.fs_scandir(
			dir,
			scheduled(function(err, handle)
				if not err then
					while true do
						local name, kind = vim.uv.fs_scandir_next(handle)
						if not name then
							break
						end
						local path = vim.fs.joinpath(dir, name)
						if kind == "file" and (not opts.match or opts.match(name, path)) then
							table.insert(files, path)
						elseif
							kind == "directory"
							and depth < max_depth
							and (not opts.skip_dir or not opts.skip_dir(name, path))
						then
							pending = pending + 1
							scan(path, depth + 1)
						end
					end
				end
				complete()
			end)
		)
	end

	scan(root, 0)
end

return M
