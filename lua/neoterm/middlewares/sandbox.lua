local writable_dirs = {
	"~/.local/share/pnpm",
	"~/.local/state/pnpm",
	vim.fs.joinpath(vim.env.XDG_STATE_HOME or vim.fs.joinpath(vim.env.HOME, ".local/state"), "nvim"),
	"~/.cache/pnpm",
}

local source_schema = vim.fs.joinpath(vim.env.HOME, ".config/varlock/env.agent.schema")
local proxy_schema = vim.fs.joinpath(vim.fn.stdpath("cache"), "neoterm", "env.agent.schema")
local proxy_dir = vim.fs.dirname(proxy_schema)
local proxy_job
local cached_session

local function session_alive(session)
	local cert = session.env and session.env.NODE_EXTRA_CA_CERTS
	return type(session.ownerPid) == "number"
		and vim.uv.kill(session.ownerPid, 0) ~= nil
		and cert ~= nil
		and vim.uv.fs_stat(cert) ~= nil
end

local function find_proxy_session()
	local result = vim.system({ "varlock", "proxy", "status", "--format", "json" }, { text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	local ok, sessions = pcall(vim.json.decode, result.stdout)
	if not ok or type(sessions) ~= "table" then
		return nil
	end
	for _, session in ipairs(sessions) do
		if session.cwd == proxy_dir and vim.tbl_contains(session.entryPaths or {}, proxy_schema) then
			return session
		end
	end
end

local function ensure_proxy()
	require("neoterm.proxy_schema").ensure(source_schema, proxy_schema)
	if cached_session and session_alive(cached_session) then
		return cached_session
	end
	cached_session = nil
	local session = find_proxy_session()
	if session then
		cached_session = session
		return session
	end
	if not proxy_job or vim.fn.jobwait({ proxy_job }, 0)[1] ~= -1 then
		proxy_job = vim.fn.jobstart({ "varlock", "proxy", "start", "--path", proxy_schema }, { cwd = proxy_dir })
		assert(proxy_job > 0, "Failed to start the shared varlock proxy")
	end
	vim.wait(10000, function()
		session = find_proxy_session()
		return session ~= nil or vim.fn.jobwait({ proxy_job }, 0)[1] ~= -1
	end, 100)
	cached_session = assert(session, "Shared varlock proxy did not start")
	return cached_session
end

vim.api.nvim_create_autocmd("ExitPre", {
	callback = function()
		if proxy_job and vim.fn.jobwait({ proxy_job }, 0)[1] == -1 then
			vim.fn.jobstop(proxy_job)
		end
	end,
})

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
		local session = ensure_proxy()
		local cwd = vim.fs.abspath(opts.cwd)
		local artifacts = vim.fs.abspath(opts.artifacts_dir or require("neoterm.config").dirs.artifacts)
		local cmd = {
			"varlock",
			"proxy",
			"run",
			"--session",
			session.id,
			"--inject",
			"vars",
			"--",
		}
		vim.list_extend(cmd, {
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
		})
		local cert_file = assert(session.env and session.env.NODE_EXTRA_CA_CERTS, "Varlock proxy has no CA certificate")
		local cert_dir = vim.fs.dirname(cert_file)
		-- Varlock's CA lives under /tmp, which the sandbox replaces above.
		vim.list_extend(cmd, { "--dir", cert_dir, "--ro-bind", cert_dir, cert_dir })
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
