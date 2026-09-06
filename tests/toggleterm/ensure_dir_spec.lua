local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				function run_ensure_dir_case(associated_cwd)
					local calls = { create = {} }
					local cwd = vim.fn.getcwd()
					local bufnr = vim.api.nvim_get_current_buf()
					vim.api.nvim_buf_set_name(bufnr, "/shared/artifacts/feature/spec.md")
					vim.b[bufnr].my_rooter_symlink_cwd = associated_cwd

					package.loaded["plugins.toggleterm.terms.window"] = {
						get_path = function() return "README.md" end,
						create = function(path) table.insert(calls.create, path) end,
					}
					package.loaded["my.windows"] = {
						get_last_file_win = function() return vim.api.nvim_get_current_win() end,
					}
					dofile(cwd .. "/lua/plugins/toggleterm/terms/ensure_dir.lua").ensure_dir(cwd)
					return calls
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["keeps a rooter-associated artifact buffer for the requested cwd"] = function()
	local calls = child.lua_get([[run_ensure_dir_case(vim.fn.getcwd())]])
	assert.same({}, calls.create)
end

T["replaces an artifact buffer associated with another cwd"] = function()
	local calls = child.lua_get([[run_ensure_dir_case("/another/repo")]])
	assert.same({ vim.fs.joinpath(vim.fn.getcwd(), "README.md") }, calls.create)
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

return T
