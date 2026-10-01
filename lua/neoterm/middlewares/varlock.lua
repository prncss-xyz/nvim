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

local function bind_certificate(cmd, cert_file)
	if cmd[1] ~= "bwrap" then
		return
	end
	local cert_dir = vim.fs.dirname(cert_file)
	for i, arg in ipairs(cmd) do
		if arg == "--" then
			-- bwrap replaces /tmp, where the proxy keeps its CA certificate.
			local bind = { "--dir", cert_dir, "--ro-bind", cert_dir, cert_dir }
			for j = #bind, 1, -1 do
				table.insert(cmd, i, bind[j])
			end
			return
		end
	end
	error("Sandbox command has no separator")
end

return function(opts)
	if opts.varlock ~= true then
		return opts
	end
	local session = ensure_proxy()
	local inner_cmd = command(opts.cmd)
	local cert_file = assert(session.env and session.env.NODE_EXTRA_CA_CERTS, "Varlock proxy has no CA certificate")
	bind_certificate(inner_cmd, cert_file)
	local cmd = { "varlock", "proxy", "run", "--session", session.id, "--inject", "vars", "--" }
	vim.list_extend(cmd, inner_cmd)
	opts.cmd = cmd
	opts.varlock = nil
	return opts
end
