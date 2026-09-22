local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. package.path
				file = require("lualine.components.file")
				vim.api.nvim_buf_set_name(0, "/outside/first.lua")
				editor = vim.api.nvim_get_current_win()
				file()
				vim.cmd.new()
				vim.bo.buftype = "nofile"
				panel = vim.api.nvim_get_current_win()
			]])
		end,
		post_once = child.stop,
	},
})

T["tracks files opened between renders while a panel retains focus"] = function()
	child.lua([[
		vim.api.nvim_win_call(editor, function()
			vim.cmd.edit("/outside/second.lua")
		end)
	]])
	assert.same(true, child.lua_get("vim.api.nvim_get_current_win() == panel"))
	assert.same(true, child.lua_get("file():find('second.lua', 1, true) ~= nil"))
end

T["tracks an existing buffer installed in the editor window"] = function()
	child.lua([[
		local buffer = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buffer, "/outside/existing.lua")
		vim.api.nvim_win_set_buf(editor, buffer)
	]])
	assert.same(true, child.lua_get("file():find('existing.lua', 1, true) ~= nil"))
end

T["renders live modified state while focused on a panel"] = function()
	child.lua("vim.bo[vim.api.nvim_win_get_buf(editor)].modified = true")
	assert.same(true, child.lua_get("file():find('', 1, true) ~= nil"))
end

T["does not display the panel name"] = function()
	child.lua("vim.api.nvim_buf_set_name(0, 'task-panel')")
	assert.same(true, child.lua_get("file():find('first.lua', 1, true) ~= nil"))
end

T["handles deletion of the remembered file buffer"] = function()
	child.lua("vim.api.nvim_buf_delete(vim.api.nvim_win_get_buf(editor), { force = true })")
	assert.same("string", child.lua_get("type(file())"))
end

T["finds the editor when first loaded inside a panel"] = function()
	child.lua([[
		package.loaded["lualine.components.file"] = nil
		vim.t.lualine_file_win = nil
		file = require("lualine.components.file")
	]])
	assert.same(true, child.lua_get("file():find('first.lua', 1, true) ~= nil"))
	child.lua([[
		vim.api.nvim_win_call(editor, function()
			vim.cmd.edit("/outside/startup.lua")
		end)
	]])
	assert.same(true, child.lua_get("file():find('startup.lua', 1, true) ~= nil"))
end

T["reads the live window even when buffer events were missed"] = function()
	child.lua([[
		vim.api.nvim_win_call(editor, function()
			vim.cmd("noautocmd edit /outside/missed.lua")
		end)
	]])
	assert.same(true, child.lua_get("file():find('missed.lua', 1, true) ~= nil"))
end

T["does not reuse a file window from another tab"] = function()
	child.lua([[
		vim.cmd.tabnew()
		vim.bo.buftype = "nofile"
	]])
	assert.same("", child.lua_get("file()"))
end

T["displays an unlisted file buffer opened directly by a panel"] = function()
	child.lua([[
		local path = vim.fn.tempname() .. ".md"
		vim.fn.writefile({ "task" }, path)
		opened_path = path
		local buffer = vim.fn.bufadd(path)
		vim.api.nvim_win_set_buf(editor, buffer)
		vim.api.nvim_set_current_win(editor)
	]])
	assert.same(false, child.lua_get("vim.bo.buflisted"))
	assert.same(true, child.lua_get("file():find(vim.fs.basename(opened_path), 1, true) ~= nil"))
	child.lua("vim.api.nvim_set_current_win(panel)")
	assert.same(true, child.lua_get("file():find(vim.fs.basename(opened_path), 1, true) ~= nil"))
	child.lua("vim.fn.delete(opened_path)")
end

return T
