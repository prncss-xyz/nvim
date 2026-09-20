local T = MiniTest.new_set()

T["bwrap sandbox"] = function()
	local sandbox = require("neoterm.terms.middleware.sandbox")
	local item = sandbox.sandbox({
		sandbox = "bwrap",
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		writable_paths = { "/tmp/pi-agent" },
		cmd = { "printf", "%s", "hello world" },
	})

	assert.same({
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
		"/tmp/artifacts",
		"/tmp/artifacts",
		"--bind",
		vim.fs.abspath("~/.local/share/pnpm"),
		vim.fs.abspath("~/.local/share/pnpm"),
		"--bind",
		vim.fs.abspath("~/.local/state/pnpm"),
		vim.fs.abspath("~/.local/state/pnpm"),
		"--bind",
		vim.fs.abspath("~/.cache/pnpm"),
		vim.fs.abspath("~/.cache/pnpm"),
		"--bind",
		"/tmp/pi-agent",
		"/tmp/pi-agent",
		"--bind",
		"/tmp/project",
		"/tmp/project",
		"--chdir",
		"/tmp/project",
		"--",
		"printf",
		"%s",
		"hello world",
	}, item.cmd)
	assert(item.sandbox == nil)
end

T["bwrap sandbox preserves shell commands"] = function()
	local sandbox = require("neoterm.terms.middleware.sandbox")
	local item = sandbox.sandbox({
		sandbox = "bwrap",
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		writable_paths = { "/tmp/pi-agent" },
		cmd = "printf 'hello world'",
	})

	assert.same(
		{ vim.o.shell, vim.o.shellcmdflag, "printf 'hello world'" },
		vim.list_slice(item.cmd, #item.cmd - 2, #item.cmd)
	)
end

return T