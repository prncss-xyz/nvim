local M = {}

local writable_paths = {
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

M.builders = {
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
			"--bind",
			artifacts,
			artifacts,
		}
		for _, path in ipairs(vim.list_extend(vim.deepcopy(writable_paths), opts.writable_paths or {})) do
			path = vim.fs.abspath(path)
			vim.list_extend(cmd, { "--bind", path, path })
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

function M.sandbox(opts)
	local builder = assert(M.builders[opts.sandbox], "Unknown sandbox: " .. opts.sandbox)
	opts.cmd = builder(opts)
	opts.sandbox = nil
	return opts
end

return M