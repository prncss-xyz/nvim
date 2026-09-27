local T = MiniTest.new_set()

T["bwrap sandbox"] = function()
	local sandbox = require("neoterm.middlewares.sandbox")
	local writable_file = vim.fn.tempname()
	local item = sandbox({
		sandbox = "bwrap",
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		writable_dirs = { "/tmp/pi-agent" },
		writable_files = { writable_file },
		cmd = { "printf", "%s", "hello world" },
	})

	assert.same({
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
		"/tmp/artifacts",
		"/tmp/artifacts",
		"--bind",
		vim.fs.abspath("~/.local/share/pnpm"),
		vim.fs.abspath("~/.local/share/pnpm"),
		"--bind",
		vim.fs.abspath("~/.local/state/pnpm"),
		vim.fs.abspath("~/.local/state/pnpm"),
		"--bind",
		vim.fs.abspath(vim.env.XDG_STATE_HOME or vim.fs.joinpath(vim.env.HOME, ".local/state")) .. "/nvim",
		vim.fs.abspath(vim.env.XDG_STATE_HOME or vim.fs.joinpath(vim.env.HOME, ".local/state")) .. "/nvim",
		"--bind",
		vim.fs.abspath("~/.cache/pnpm"),
		vim.fs.abspath("~/.cache/pnpm"),
		"--bind",
		"/tmp/pi-agent",
		"/tmp/pi-agent",
		"--bind-try",
		writable_file,
		writable_file,
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
	assert(vim.fn.isdirectory(writable_file) == 0)
	assert(item.sandbox == nil)
end

T["bwrap sandbox preserves shell commands"] = function()
	local sandbox = require("neoterm.middlewares.sandbox")
	local item = sandbox({
		sandbox = "bwrap",
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		writable_dirs = { "/tmp/pi-agent" },
		cmd = "printf 'hello world'",
	})

	assert.same(
		{ vim.o.shell, vim.o.shellcmdflag, "printf 'hello world'" },
		vim.list_slice(item.cmd, #item.cmd - 2, #item.cmd)
	)
end

T["bwrap sandbox binds linked worktree metadata"] = function()
	local root = vim.fn.tempname()
	local main = root .. "/main"
	local worktree = root .. "/worktree"
	vim.fn.mkdir(main, "p")
	local function git(args)
		local output = vim.fn.system(vim.list_extend({ "git" }, args))
		assert(vim.v.shell_error == 0, output)
	end
	git({ "-C", main, "init", "-q" })
	git({
		"-C",
		main,
		"-c",
		"user.name=Test",
		"-c",
		"user.email=test@example.com",
		"commit",
		"-q",
		"--allow-empty",
		"-m",
		"initial",
	})
	git({ "-C", main, "worktree", "add", "-q", "-b", "sandbox-test", worktree })

	local item = require("neoterm.middlewares.sandbox")({
		sandbox = "bwrap",
		cwd = worktree,
		artifacts_dir = root,
		cmd = { "true" },
	})
	local common = main .. "/.git"
	local worktree_git = common .. "/worktrees/worktree"
	local function has_bind(path)
		for i = 1, #item.cmd - 2 do
			if item.cmd[i] == "--bind" and item.cmd[i + 1] == path and item.cmd[i + 2] == path then
				return true
			end
		end
		return false
	end
	assert(has_bind(common))
	assert(has_bind(worktree_git))
	vim.fn.delete(root, "rf")
end

return T
