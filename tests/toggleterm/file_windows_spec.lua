local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
				history = require("neoterm.helpers.win_history")
				policy = require("neoterm.helpers.file_windows")
				original = vim.api.nvim_get_current_win()
				vim.api.nvim_buf_set_name(0, "/outside/file.lua")
				selected = 0
				package.loaded["neoterm.helpers.project_file"] = {
					get_project_file = function()
						selected = selected + 1
						return "/project/chosen.lua"
					end,
				}
				package.loaded["neoterm.terms.window"] = {}
				package.loaded["neoterm.terms.artifacts.cwd"] = { contains = function() return false end }
				ensure = require("neoterm.helpers.ensure_dir").ensure_dir
			]])
		end,
		post_once = child.stop,
	},
})

T["matching fixed-buffer window satisfies visibility without choosing a file"] = function()
	child.lua([[
		vim.api.nvim_buf_set_name(0, "/project/another.lua")
		vim.wo.winfixbuf = true
		vim.cmd.new()
		vim.bo.buftype = "nofile"
		ensure("/project")
	]])
	assert.same(0, child.lua_get("selected"))
	assert.same(true, child.lua_get("vim.api.nvim_get_current_win() == original"))
end

T["matching float does not satisfy visibility or receive replacement"] = function()
	child.lua([[
		local buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buf, "/project/floating.lua")
		floating = vim.api.nvim_open_win(buf, true, { relative = "editor", row = 0, col = 0, width = 20, height = 5 })
		ensure("/project")
	]])
	assert.same(1, child.lua_get("selected"))
	assert.same("/project/chosen.lua", child.lua_get("vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(original))"))
	assert.same("/project/floating.lua", child.lua_get("vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(floating))"))
end

T["excluded visible file does not satisfy visibility"] = function()
	child.lua([[
		vim.api.nvim_buf_set_name(0, "/project/excluded/file.lua")
		ensure("/project", { "/project/excluded" })
	]])
	assert.same(1, child.lua_get("selected"))
	assert.same("/project/chosen.lua", child.lua_get("vim.api.nvim_buf_get_name(0)"))
end

T["no replaceable window is a silent no-op"] = function()
	child.lua([[
		vim.wo.winfixbuf = true
		vim.cmd.new()
		vim.bo.buftype = "nofile"
		before = vim.api.nvim_get_current_win()
		count = #vim.api.nvim_tabpage_list_wins(0)
		ensure("/project")
	]])
	assert.same(0, child.lua_get("selected"))
	assert.same(
		true,
		child.lua_get("before == vim.api.nvim_get_current_win() and count == #vim.api.nvim_tabpage_list_wins(0)")
	)
end

T["artifact protection remains intact"] = function()
	child.lua([[
		package.loaded["neoterm.terms.artifacts.cwd"].contains = function() return true end
		ensure("/project")
	]])
	assert.same(0, child.lua_get("selected"))
	assert.same("/outside/file.lua", child.lua_get("vim.api.nvim_buf_get_name(0)"))
end

T["current eligible window wins over history"] = function()
	child.lua([[
		history.on_win_enter()
		vim.cmd.new()
	]])
	assert.same(true, child.lua_get("history.get_last_file_win() == vim.api.nvim_get_current_win()"))
end

T["uses real history beyond the alternate utility window"] = function()
	child.lua([[
		vim.cmd.new()
		vim.api.nvim_set_current_win(original)
		history.on_win_enter()
		vim.cmd.new()
		vim.bo.buftype = "nofile"
		history.on_win_enter()
		vim.cmd.new()
		vim.bo.buftype = "nofile"
		history.on_win_enter()
	]])
	assert.same(true, child.lua_get("history.get_last_file_win() == original"))
end

T["skips stale and protected history entries"] = function()
	child.lua([[
		history.on_win_enter()
		vim.cmd.new()
		history.on_win_enter()
		vim.api.nvim_win_close(0, true)
		vim.cmd.new()
		vim.wo.winfixbuf = true
		history.on_win_enter()
		vim.cmd.new()
		vim.bo.filetype = "neotest-summary"
		history.on_win_enter()
	]])
	assert.same(true, child.lua_get("history.get_last_file_win() == original"))
end

T["falls back without history and stays in the current tab"] = function()
	child.lua([[
		vim.cmd.new()
		vim.bo.buftype = "nofile"
	]])
	assert.same(true, child.lua_get("history.get_last_file_win() == original"))
	child.lua([[
		vim.cmd.tabnew()
		vim.bo.buftype = "nofile"
	]])
	assert.same(true, child.lua_get("history.get_last_file_win() == nil and not policy.can_focus(original)"))
end

return T
