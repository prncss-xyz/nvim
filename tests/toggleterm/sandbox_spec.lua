local original_system = vim.system
local original_jobstart = vim.fn.jobstart
local original_jobwait = vim.fn.jobwait
local original_proxy_schema = package.loaded["neoterm.proxy_schema"]
local cert_dir = vim.fn.tempname()
local cert_file = vim.fs.joinpath(cert_dir, "ca-cert.pem")
local sources = { "/tmp/agent.env.schema", "/tmp/other.env.schema" }
local starts = {}
local lookups = 0
local ensured = {}
local function proxy_paths(source)
	local dir = vim.fs.joinpath(vim.fn.stdpath("cache"), "neoterm", "varlock", vim.fn.sha256(source))
	return dir, vim.fs.joinpath(dir, vim.fs.basename(source))
end
local T = MiniTest.new_set({
	hooks = {
		pre_once = function()
			vim.fn.mkdir(cert_dir, "p")
			vim.fn.writefile({ "test certificate" }, cert_file)
			package.loaded["neoterm.proxy_schema"] = {
				ensure = function(source, target)
					ensured[source] = target
					return target
				end,
			}
			vim.system = function(cmd, opts)
				if cmd[1] == "varlock" then
					lookups = lookups + 1
					local sessions = {}
					for source, id in pairs(starts) do
						local dir, path = proxy_paths(source)
						table.insert(sessions, {
							id = id,
							ownerPid = vim.fn.getpid(),
							cwd = dir,
							entryPaths = { path },
							env = { NODE_EXTRA_CA_CERTS = cert_file },
						})
					end
					return { wait = function() return { code = 0, stdout = vim.json.encode(sessions) } end }
				end
				return original_system(cmd, opts)
			end
			vim.fn.jobstart = function(cmd, opts)
				if cmd[1] == "varlock" then
					for _, source in ipairs(sources) do
						local dir, path = proxy_paths(source)
						if cmd[5] == path then
							assert.same(dir, opts.cwd)
							starts[source] = "proxy-" .. vim.fn.sha256(source):sub(1, 8)
							return 123456 + vim.tbl_count(starts)
						end
					end
					error("Unexpected proxy schema: " .. tostring(cmd[5]))
				end
				return original_jobstart(cmd, opts)
			end
			vim.fn.jobwait = function(jobs, timeout)
				if jobs[1] >= 123457 and jobs[1] <= 123458 then
					return { -1 }
				end
				return original_jobwait(jobs, timeout)
			end
		end,
		post_once = function()
			vim.fn.delete(cert_dir, "rf")
			package.loaded["neoterm.proxy_schema"] = original_proxy_schema
			vim.system = original_system
			vim.fn.jobstart = original_jobstart
			vim.fn.jobwait = original_jobwait
		end,
	},
})

local function wrapped(source)
	local item = {
		sandbox = "bwrap",
		varlock = source,
		cwd = "/tmp/project",
		artifacts_dir = "/tmp/artifacts",
		cmd = { "printf", "%s", "hello world" },
	}
	item = require("neoterm.middlewares.sandbox")(item)
	return require("neoterm.middlewares.varlock")(item)
end

T["varlock wraps sandbox and binds certificate"] = function()
	local item = wrapped(sources[1])
	assert.same({ "varlock", "proxy", "run", "--session", starts[sources[1]], "--inject", "vars", "--", "bwrap" },
		vim.list_slice(item.cmd, 1, 9))
	local function contains(sequence)
		for i = 1, #item.cmd - #sequence + 1 do
			if vim.deep_equal(vim.list_slice(item.cmd, i, i + #sequence - 1), sequence) then return true end
		end
		return false
	end
	assert(contains({ "--dir", cert_dir, "--ro-bind", cert_dir, cert_dir }))
	assert.same({ "printf", "%s", "hello world" }, vim.list_slice(item.cmd, #item.cmd - 2, #item.cmd))
	assert(item.sandbox == nil and item.varlock == nil)
end

T["one proxy per schema path, reused on demand"] = function()
	wrapped(sources[1])
	local first_lookups = lookups
	wrapped(sources[1])
	assert.same(first_lookups, lookups)
	wrapped(sources[2])
	assert.same(2, vim.tbl_count(starts))
	assert(ensured[sources[1]] ~= ensured[sources[2]])
	assert.same(starts[sources[2]], wrapped(sources[2]).cmd[5])
end

T["invalid varlock path is rejected"] = function()
	local ok = pcall(require("neoterm.middlewares.varlock"), { varlock = true, cmd = { "true" } })
	assert(not ok)
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
