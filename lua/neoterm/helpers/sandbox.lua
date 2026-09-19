local M = {}

local function command(cmd)
	if cmd == nil then
		return { vim.o.shell }
	end
	if vim.islist(cmd) then
		return cmd
	end
	return { vim.o.shell, vim.o.shellcmdflag, cmd }
end

M.builders = {
	bwrap = function(opts)
		local cwd = vim.fs.abspath(opts.cwd)
		local dirs = (not opts.artifacts_dir or not opts.projects_dir) and require("neoterm.config").dirs or {}
		local artifacts = vim.fs.abspath(opts.artifacts_dir or dirs.artifacts)
		local projects = vim.fs.abspath(opts.projects_dir or dirs.projects)
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
			"--ro-bind",
			projects,
			projects,
			"--bind",
			artifacts,
			artifacts,
			"--bind",
			cwd,
			cwd,
			"--chdir",
			cwd,
			"--",
		}
		vim.list_extend(cmd, command(opts.cmd))
		return cmd
	end,
}

function M.sandbox(opts)
	local builder = assert(M.builders[opts.sandbox], "Unknown sandbox: " .. opts.sandbox)
	opts.cmd = builder(opts)
	opts.sandbox = nil
	return opts
end

return M