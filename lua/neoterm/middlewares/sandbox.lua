local writable_dirs = {
	"~/.local/share/pnpm",
	"~/.local/state/pnpm",
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

local builders = {
	bwrap = function(opts)
		local cwd = vim.fs.abspath(opts.cwd)
		local artifacts = vim.fs.abspath(opts.artifacts_dir or require("neoterm.config").dirs.artifacts)
		local cmd = {
			"varlock",
			"run",
			"--path",
			vim.fs.joinpath(vim.env.HOME, ".config/varlock/env.agent.schema"),
			"--inject",
			"vars",
			"--",
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
			"--bind",
			artifacts,
			artifacts,
		}
		for _, path in ipairs(vim.list_extend(vim.deepcopy(writable_dirs), opts.writable_dirs or {})) do
			path = vim.fs.abspath(path)
			vim.fn.mkdir(path, "p")
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
