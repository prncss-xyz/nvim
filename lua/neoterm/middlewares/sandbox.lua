local writable_dirs = {
	"~/.local/share/pnpm",
	"~/.local/state/pnpm",
	vim.fs.joinpath(vim.env.XDG_STATE_HOME or vim.fs.joinpath(vim.env.HOME, ".local/state"), "nvim"),
	"~/.cache/pnpm",
}

local function command(cmd)
	if cmd == nil then
		return { vim.o.shell }
	end
	if vim.islist(cmd) then
		return cmd
	end
	return { vim.o.shell, vim.o.shellcmdflag, cmd }
end

local function git_metadata_dirs(cwd)
	local dirs = {}
	local seen = {}
	for _, flag in ipairs({ "--git-common-dir", "--git-dir" }) do
		local result = vim.fn.systemlist({ "git", "-C", cwd, "rev-parse", "--path-format=absolute", flag })
		if vim.v.shell_error == 0 then
			local path = vim.fs.abspath(result[1])
			if not seen[path] then
				seen[path] = true
				table.insert(dirs, path)
			end
		end
	end
	return dirs
end

local builders = {
	bwrap = function(opts)
		local cwd = vim.fs.abspath(opts.cwd)
		local artifacts = vim.fs.abspath(opts.artifacts_dir or require("neoterm.config").dirs.artifacts)
		local cmd = {
			"bwrap",
			"--die-with-parent",
			"--new-session",
			"--unshare-all",
			"--share-net",
			"--ro-bind",
			"/",
			"/",
			"--dev",
			"/dev",
			"--proc",
			"/proc",
			"--tmpfs",
			"/tmp",
		}
		vim.list_extend(cmd, {
			"--bind",
			artifacts,
			artifacts,
		})
		for _, path in ipairs(vim.list_extend(vim.deepcopy(writable_dirs), opts.writable_dirs or {})) do
			path = vim.fs.abspath(path)
			vim.fn.mkdir(path, "p")
			vim.list_extend(cmd, { "--bind", path, path })
		end
		-- Linked worktrees keep their index and refs outside cwd. Bind existing Git
		-- metadata separately; unlike writable_dirs, never create these paths.
		for _, path in ipairs(git_metadata_dirs(cwd)) do
			vim.list_extend(cmd, { "--bind", path, path })
		end
		for _, path in ipairs(opts.writable_files or {}) do
			path = vim.fs.abspath(path)
			vim.list_extend(cmd, { "--bind-try", path, path })
		end
		vim.list_extend(cmd, {
			"--bind",
			cwd,
			cwd,
			"--chdir",
			cwd,
			"--",
		})
		vim.list_extend(cmd, command(opts.cmd))
		return cmd
	end,
}

return function(opts)
	if opts.sandbox == nil then
		return opts
	end
	local builder = assert(builders[opts.sandbox], "Unknown sandbox: " .. opts.sandbox)
	opts.cmd = builder(opts)
	opts.sandbox = nil
	return opts
end
