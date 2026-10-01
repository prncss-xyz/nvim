local original_system = vim.system
local original_jobstart = vim.fn.jobstart
local original_jobwait = vim.fn.jobwait
local original_proxy_schema = package.loaded["neoterm.proxy_schema"]
local proxy_starts = 0
local proxy_dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "neoterm")
local proxy_schema = vim.fs.joinpath(proxy_dir, "env.agent.schema")
local T = MiniTest.new_set({
	hooks = {
		pre_once = function()
			package.loaded["neoterm.proxy_schema"] = {
				ensure = function(_, target)
					return target
				end,
			}
			vim.system = function(cmd, opts)
				if cmd[1] == "varlock" then
					return {
						wait = function()
							return {
								code = 0,
								stdout = proxy_starts == 0 and "[]" or vim.json.encode({
									{
										id = "agent-proxy",
										cwd = proxy_dir,
										entryPaths = { proxy_schema },
										env = { NODE_EXTRA_CA_CERTS = "/tmp/varlock-proxy-certs-test/ca-cert.pem" },
									},
								}),
							}
						end,
					}
				end
				return original_system(cmd, opts)
			end
			vim.fn.jobstart = function(cmd, opts)
				if cmd[1] == "varlock" then
					assert.same(proxy_dir, opts.cwd)
					proxy_starts = proxy_starts + 1
					return 123456
				end
				return original_jobstart(cmd, opts)
			end
			vim.fn.jobwait = function(jobs, timeout)
				if jobs[1] == 123456 then
					return { -1 }
				end
				return original_jobwait(jobs, timeout)
			end
		end,
		post_once = function()
			package.loaded["neoterm.proxy_schema"] = original_proxy_schema
			vim.system = original_system
			vim.fn.jobstart = original_jobstart
			vim.fn.jobwait = original_jobwait
		end,
	},
})

T["bwrap sandbox"] = function()
	local sandbox = require("neoterm.middlewares.sandbox")
	local writable_file = vim.fn.tempname()
	local item = sandbox({
		sandbox = "bwrap",
		agent = "codex",
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		writable_dirs = { "/tmp/pi-agent" },
		writable_files = { writable_file },
		cmd = { "printf", "%s", "hello world" },
	})

	assert.same({
		"varlock",
		"proxy",
		"run",
		"--session",
		"agent-proxy",
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
		"--dir",
		"/tmp/varlock-proxy-certs-test",
		"--ro-bind",
		"/tmp/varlock-proxy-certs-test",
		"/tmp/varlock-proxy-certs-test",
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
	assert.same(1, proxy_starts)
	assert(vim.fn.isdirectory(writable_file) == 0)
	assert(item.sandbox == nil)
end

T["bwrap sandbox preserves shell commands"] = function()
	local sandbox = require("neoterm.middlewares.sandbox")
	local item = sandbox({
		sandbox = "bwrap",
		agent = "codex",
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

T["pi attaches to the shared proxy"] = function()
	local starts = proxy_starts
	local item = require("neoterm.middlewares.sandbox")({
		sandbox = "bwrap",
		agent = "pi",
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		cmd = { "pi", "--provider", "opencode-go" },
	})
	assert.same(
		{ "varlock", "proxy", "run", "--session", "agent-proxy", "--inject", "vars", "--", "bwrap" },
		vim.list_slice(item.cmd, 1, 9)
	)
	assert.same(starts, proxy_starts)
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
		"commit.gpgsign=false",
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
		agent = "codex",
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
