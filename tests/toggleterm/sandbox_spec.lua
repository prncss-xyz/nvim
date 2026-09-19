local T = MiniTest.new_set()

T["bwrap sandbox"] = function()
	local sandbox = require("neoterm.helpers.sandbox")
	local item = sandbox.sandbox({
		sandbox = "bwrap",
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		projects_dir = "/tmp/projects",
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
		"--ro-bind",
		"/tmp/projects",
		"/tmp/projects",
		"--bind",
		"/tmp/artifacts",
		"/tmp/artifacts",
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
	local sandbox = require("neoterm.helpers.sandbox")
	local item = sandbox.sandbox({
		sandbox = "bwrap",
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		projects_dir = "/tmp/projects",
		cmd = "printf 'hello world'",
	})

	assert.same(
		{ vim.o.shell, vim.o.shellcmdflag, "printf 'hello world'" },
		vim.list_slice(item.cmd, #item.cmd - 2, #item.cmd)
	)
end

return T