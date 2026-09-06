local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.preload["my.create"] = function()
					return {
						create = function(path)
							vim.fn.mkdir(vim.fs.dirname(path), "p")
							vim.cmd.edit(vim.fn.fnameescape(path))
							vim.cmd.write()
						end,
					}
				end

				function focused_path_case(file, cwd, item_cwd)
					local result
					local picker = {
						current = function() return { file = file, cwd = item_cwd } end,
						cwd = function() return cwd end,
						input = { set = function(_, value) result = value end },
					}
					dofile(vim.fn.getcwd() .. "/lua/plugins/snacks/create_file.lua").use_focused_path(picker)
					return result
				end

				function create_file_case(cwd, name)
					local calls = { closed = false }
					local picker = {
						opts = { format = "file" },
						input = { filter = { pattern = name } },
						cwd = function() return cwd end,
						close = function() calls.closed = true end,
					}
					dofile(vim.fn.getcwd() .. "/lua/plugins/snacks/create_file.lua").create(picker)
					calls.path = vim.api.nvim_buf_get_name(0)
					calls.exists = vim.uv.fs_stat(calls.path) ~= nil
					return calls
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["uses the focused entry directory relative to the picker cwd with one trailing slash"] = function()
	local cwd = "/project"
	assert.same("notes/", child.lua_get([[focused_path_case(...)]], { "/project/notes/existing.md", cwd }))
	assert.same("notes/", child.lua_get([[focused_path_case(...)]], { "notes/existing.md", cwd }))
	assert.same("", child.lua_get([[focused_path_case(...)]], { "existing.md", cwd }))
	assert.same("notes/", child.lua_get([[focused_path_case(...)]], { "existing.md", cwd, "/project/notes" }))
end

T["creates and opens the prompted file relative to the picker cwd"] = function()
	local cwd = vim.fn.tempname()
	vim.fn.mkdir(cwd, "p")
	local calls = child.lua_get([[create_file_case(...)]], { cwd, "notes/new.md" })

	assert.same({
		closed = true,
		exists = true,
		path = vim.fs.joinpath(cwd, "notes/new.md"),
	}, calls)
end

return T
