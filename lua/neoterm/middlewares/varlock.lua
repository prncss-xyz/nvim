local proxies = {}

local function proxy_for(source_schema)
	local proxy_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "neoterm", "varlock", vim.fn.sha256(source_schema))
	return {
		source_schema = source_schema,
		proxy_dir = proxy_dir,
		proxy_schema = vim.fs.joinpath(proxy_dir, vim.fs.basename(source_schema)),
	}
end

local function session_alive(session)
	local cert = session.env and session.env.NODE_EXTRA_CA_CERTS
	return type(session.ownerPid) == "number"
		and vim.uv.kill(session.ownerPid, 0) ~= nil
		and cert ~= nil
		and vim.uv.fs_stat(cert) ~= nil
end

local function find_proxy_session(proxy)
	local result = vim.system({ "varlock", "proxy", "status", "--format", "json" }, { text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	local ok, sessions = pcall(vim.json.decode, result.stdout)
	if not ok or type(sessions) ~= "table" then
		return nil
	end
	for _, session in ipairs(sessions) do
		if session.cwd == proxy.proxy_dir and vim.tbl_contains(session.entryPaths or {}, proxy.proxy_schema) then
			return session
		end
	end
end

local function ensure_proxy(source_schema)
	local proxy = proxies[source_schema]
	if not proxy then
		proxy = proxy_for(source_schema)
		proxies[source_schema] = proxy
	end
	require("neoterm.proxy_schema").ensure(proxy.source_schema, proxy.proxy_schema)
	if proxy.session and session_alive(proxy.session) then
		return proxy.session
	end
	proxy.session = nil
	local session = find_proxy_session(proxy)
	if session then
		proxy.session = session
		return session
	end
	if not proxy.job or vim.fn.jobwait({ proxy.job }, 0)[1] ~= -1 then
		proxy.output = {}
		local function capture(_, lines)
			vim.list_extend(proxy.output, lines)
		end
		proxy.job = vim.fn.jobstart({ "varlock", "proxy", "start", "--path", proxy.proxy_schema }, {
			cwd = proxy.proxy_dir,
			on_stdout = capture,
			on_stderr = capture,
		})
		assert(proxy.job > 0, "Failed to start the varlock proxy for " .. source_schema)
	end
	vim.wait(10000, function()
		session = find_proxy_session(proxy)
		return session ~= nil or vim.fn.jobwait({ proxy.job }, 0)[1] ~= -1
	end, 100)
	if not session then
		local output = table.concat(proxy.output or {}, "\n")
		if output:find("GPG decryption failed", 1, true) then
			error("Varlock could not decrypt the secrets in " .. source_schema
			.. ". Check that your GPG key and agent are available, then retry."
			.. " Run `gpg --list-secret-keys` and `gpgconf --launch gpg-agent` if needed.", 0)
		end
		error("Varlock proxy did not start for " .. source_schema .. ". Run `varlock proxy start --path "
			.. proxy.proxy_schema .. "` for details.", 0)
	end
	proxy.session = session
	return proxy.session
end

vim.api.nvim_create_autocmd("ExitPre", {
	callback = function()
		for _, proxy in pairs(proxies) do
			if proxy.job and vim.fn.jobwait({ proxy.job }, 0)[1] == -1 then
				vim.fn.jobstop(proxy.job)
			end
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
	if opts.varlock == nil or opts.varlock == false then
		return opts
	end
	assert(type(opts.varlock) == "string" and opts.varlock ~= "", "varlock must be a schema path")
	local session = ensure_proxy(vim.fs.abspath(opts.varlock))
	local inner_cmd = command(opts.cmd)
	local cert_file = assert(session.env and session.env.NODE_EXTRA_CA_CERTS, "Varlock proxy has no CA certificate")
	bind_certificate(inner_cmd, cert_file)
	local cmd = { "varlock", "proxy", "run", "--session", session.id, "--inject", "vars", "--" }
	vim.list_extend(cmd, inner_cmd)
	opts.cmd = cmd
	opts.varlock = nil
	return opts
end
