local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["focuses the first window with a buffer inside the requested directory"] = function()
	child.lua([[
		local cwd = vim.fn.getcwd()
		local inside = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_set_name(inside, cwd .. "/lua/example.lua")
		vim.cmd.new()
		vim.api.nvim_buf_set_name(0, "/outside/repo/file.md")
		package.loaded["plugins.toggleterm.terms.window"] = {
			get_path = function() error("should not open a file") end,
		}
		package.loaded["my.windows"] = {
			get_last_file_win = function() error("should not select a fallback window") end,
		}
		dofile(cwd .. "/lua/plugins/toggleterm/terms/ensure_dir.lua").ensure_dir(cwd)
		result = vim.api.nvim_get_current_buf() == inside
	]])

	assert.same(true, child.lua_get("result"))
end

T["focuses a hidden buffer inside a descendant directory"] = function()
	child.lua([[
		local cwd = vim.fn.getcwd()
		local target_win = vim.api.nvim_get_current_win()
		local inside = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(inside, cwd .. "/lua/plugins/example.lua")
		vim.cmd.new()
		vim.api.nvim_buf_set_name(0, "/outside/repo/file.md")
		package.loaded["plugins.toggleterm.terms.window"] = {
			get_path = function() error("should not open a file") end,
		}
		package.loaded["my.windows"] = {
			get_last_file_win = function() return target_win end,
		}
		dofile(cwd .. "/lua/plugins/toggleterm/terms/ensure_dir.lua").ensure_dir(cwd)
		result = {
			focused = vim.api.nvim_get_current_win() == target_win,
			bufnr = vim.api.nvim_win_get_buf(target_win),
			inside = inside,
		}
	]])

	local result = child.lua_get("result")
	assert.same(true, result.focused)
	assert.same(result.inside, result.bufnr)
end

T["opens the first oldfile inside the requested directory before using git"] = function()
	child.lua([[
		local cwd = vim.fn.getcwd()
		local dir = vim.fn.tempname()
		local oldfile = dir .. "/nested/old.lua"
		local created
		vim.fn.mkdir(dir .. "/nested", "p")
		vim.fn.writefile({ "return true" }, oldfile)
		vim.cmd("let v:oldfiles = " .. vim.fn.string({ oldfile }))
		vim.api.nvim_buf_set_name(0, "/outside/repo/file.md")
		package.loaded["plugins.toggleterm.terms.window"] = {
			get_path = function() return nil end,
			create = function(path) created = path end,
		}
		package.loaded["my.windows"] = {
			get_last_file_win = function() return vim.api.nvim_get_current_win() end,
		}
		dofile(cwd .. "/lua/plugins/toggleterm/terms/ensure_dir.lua").ensure_dir(dir)
		result = { expected = oldfile, actual = created or false }
		vim.fn.delete(dir, "rf")
	]])

	local result = child.lua_get("result")
	assert.same(result.expected, result.actual)
end

T["opens a file when the requested path has no remembered window"] = function()
	child.lua([[
		local cwd = vim.fn.getcwd()
		local created
		vim.api.nvim_buf_set_name(0, "/outside/repo/file.md")
		package.loaded["plugins.toggleterm.terms.window"] = {
			get_path = function() return nil end,
			create = function(path) created = path end,
		}
		package.loaded["my.windows"] = {
			get_last_file_win = function() return vim.api.nvim_get_current_win() end,
		}
		dofile(cwd .. "/lua/plugins/toggleterm/terms/ensure_dir.lua").ensure_dir(cwd)
		result = created
	]])

	local first = vim.fn.system({ "git", "-C", vim.fn.getcwd(), "ls-files" }):match("[^\n]+")
	assert.same(vim.fs.joinpath(vim.fn.getcwd(), first), child.lua_get("result"))
end

T["does nothing when the requested path is not a git repository"] = function()
	child.lua([[
		local cwd = vim.fn.getcwd()
		local dir = vim.fn.tempname()
		local created
		vim.fn.mkdir(dir, "p")
		vim.api.nvim_buf_set_name(0, "/outside/repo/file.md")
		package.loaded["plugins.toggleterm.terms.window"] = {
			get_path = function() return nil end,
			create = function(path) created = path end,
		}
		package.loaded["my.windows"] = {
			get_last_file_win = function() return vim.api.nvim_get_current_win() end,
		}
		dofile(cwd .. "/lua/plugins/toggleterm/terms/ensure_dir.lua").ensure_dir(dir)
		vim.fn.delete(dir, "rf")
		result = created ~= nil
	]])

	assert.same(false, child.lua_get("result"))
end

return T
