local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				local rooter_plugin_path = vim.fn.getcwd() .. "/plugin/rooter.lua"

				function run_rooter_case(config)
					local calls = { lstat = {}, roots = {}, cwd = {}, sync = 0 }
					local callback
					local current_cwd = config.cwd
					local current_name = config.name or ""

					package.loaded["my.conds"] = { not_vscode = function() return true end }
					package.loaded["my.parameters"] = { rooter_patterns = { ".git", ".hg", ".svn" } }
					package.loaded["plugins.toggleterm.terms"] = {
						on_dir = function() calls.sync = calls.sync + 1 end,
					}

					vim.bo.buftype = config.buftype or ""
					vim.api.nvim_create_augroup = function() return 1 end
					vim.api.nvim_create_autocmd = function(_, opts) callback = opts.callback end
					vim.api.nvim_buf_get_name = function() return current_name end
					vim.api.nvim_set_current_dir = function(path)
						table.insert(calls.cwd, path)
						current_cwd = path
					end
					vim.fn.getcwd = function() return current_cwd end
					vim.fs.root = function(_, patterns)
						table.insert(calls.roots, patterns)
						return config.root
					end
					vim.fs.find = function(predicate)
						for _, entry in ipairs(config.entries or {}) do
							if predicate(entry.name, entry.path) then
								return { vim.fs.joinpath(entry.path, entry.name) }
							end
						end
						return {}
					end
					vim.uv.fs_realpath = function(path)
						return config.realpaths and config.realpaths[path]
					end
					vim.uv.fs_lstat = function(path)
						table.insert(calls.lstat, path)
						local value = config.lstat and config.lstat[path]
						if value == "error" then error("lstat failed") end
						return value and { type = value } or nil
					end

					dofile(rooter_plugin_path)
					callback()
					if config.second then
						current_cwd = config.second.cwd or current_cwd
						current_name = config.second.name or current_name
						config.lstat = config.second.lstat or config.lstat
						config.root = config.second.root
						callback()
					end

					return { calls = calls, saved = vim.b.my_rooter_symlink_cwd }
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["symlinked descendant preserves its opening cwd"] = function()
	local result = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/repo/view/.artifacts/feature/spec.md",
		root = "/repo/main",
		lstat = { ["/repo/view/.artifacts"] = "link" },
	})]])

	assert.same("/repo/view", result.saved)
	assert.same({ "/repo/view" }, result.calls.cwd)
	assert.same(1, result.calls.sync)
	assert.same(0, #result.calls.roots)
end

T["resolved buffer names are matched back to cwd symlinks"] = function()
	local result = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/shared/artifacts/feature/spec.md",
		root = "/shared/artifacts",
		entries = { { name = ".artifacts", path = "/repo/view" } },
		lstat = { ["/repo/view/.artifacts"] = "link" },
		realpaths = { ["/repo/view/.artifacts"] = "/shared/artifacts" },
	})]])

	assert.same("/repo/view", result.saved)
	assert.same({ "/repo/view" }, result.calls.cwd)
	assert.same(0, #result.calls.roots)
end

T["a symlink at the final path component is detected"] = function()
	local result = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/repo/view/readme-link",
		root = "/repo/main",
		lstat = { ["/repo/view/readme-link"] = "link" },
	})]])

	assert.same("/repo/view", result.saved)
	assert.same({ "/repo/view/readme-link" }, result.calls.lstat)
end

T["ordinary descendants retain VCS root selection"] = function()
	local result = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/repo/view/lua/init.lua",
		root = "/repo/main",
	})]])

	assert.same(nil, result.saved)
	assert.same({ "/repo/main" }, result.calls.cwd)
	assert.same(1, #result.calls.roots)
	assert.same(1, result.calls.sync)
end

T["saved cwd persists across later buffer entries"] = function()
	local result = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/repo/view/link/spec.md",
		root = "/repo/main",
		lstat = { ["/repo/view/link"] = "link" },
		second = {
			cwd = "/somewhere/else",
			root = nil,
			lstat = {},
		},
	})]])

	assert.same("/repo/view", result.saved)
	assert.same({ "/repo/view", "/repo/view" }, result.calls.cwd)
	assert.same(0, #result.calls.roots)
	assert.same(2, result.calls.sync)
end

T["outside and sibling-prefix paths do not preserve cwd"] = function()
	local outside = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/repo/other/link/spec.md",
		root = "/repo/other",
		lstat = { ["/repo/other/link"] = "link" },
	})]])
	assert.same(nil, outside.saved)
	assert.same({}, outside.calls.lstat)
	assert.same({ "/repo/other" }, outside.calls.cwd)

	local sibling = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/repo/view-other/link/spec.md",
		root = nil,
		lstat = { ["/repo/view-other/link"] = "link" },
	})]])
	assert.same(nil, sibling.saved)
	assert.same({}, sibling.calls.lstat)
	assert.same({}, sibling.calls.cwd)
	assert.same(0, sibling.calls.sync)
end

T["ineligible buffers do not participate in symlink capture"] = function()
	local special = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/repo/view/link/spec.md",
		buftype = "nofile",
		root = "/repo/main",
		lstat = { ["/repo/view/link"] = "link" },
	})]])
	assert.same({}, special.calls.lstat)
	assert.same({}, special.calls.roots)
	assert.same({}, special.calls.cwd)

	local unnamed = child.lua_get([[run_rooter_case({ cwd = "/repo/view", name = "", root = "/repo/main" })]])
	assert.same(nil, unnamed.saved)
	assert.same({}, unnamed.calls.lstat)
	assert.same({ "/repo/main" }, unnamed.calls.cwd)

	local remote = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "oil://repo/view/link/spec.md",
		root = nil,
	})]])
	assert.same(nil, remote.saved)
	assert.same({}, remote.calls.lstat)
	assert.same({}, remote.calls.cwd)
end

T["filesystem errors are non-fatal and fall back to VCS rooting"] = function()
	local result = child.lua_get([[run_rooter_case({
		cwd = "/repo/view",
		name = "/repo/view/link/spec.md",
		root = "/repo/main",
		lstat = { ["/repo/view/link"] = "error" },
	})]])

	assert.same(nil, result.saved)
	assert.same({ "/repo/main" }, result.calls.cwd)
	assert.same(1, result.calls.sync)
end

return T
