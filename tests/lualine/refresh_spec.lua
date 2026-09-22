local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_once = function()
			local path = vim.fs.joinpath(vim.fn.getcwd(), ".tests", "lualine.nvim")
			local lock = vim.json.decode(table.concat(vim.fn.readfile("lazy-lock.json"), "\n"))["lualine.nvim"]
			if not vim.uv.fs_stat(path) then
				vim.fn.system({
					"git",
					"clone",
					"--filter=blob:none",
					"--no-checkout",
					"https://github.com/nvim-lualine/lualine.nvim.git",
					path,
				})
				assert.same(0, vim.v.shell_error)
			end
			vim.fn.system({ "git", "-C", path, "checkout", "--detach", lock.commit })
			assert.same(0, vim.v.shell_error)
		end,
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				vim.opt.rtp:prepend(vim.fn.getcwd())
				vim.opt.rtp:prepend(vim.fn.getcwd() .. "/.tests/lualine.nvim")
				local plugin = require("plugins.lualine")[1]
				plugin.config(nil, {
					options = { globalstatus = true, theme = "auto" },
					sections = {
						lualine_a = { function() return "VISIBLE" end },
						lualine_b = { "file" },
					},
				})
				editor = vim.api.nvim_get_current_win()
				vim.cmd.vsplit()
				panel_win = vim.api.nvim_get_current_win()
				local panel = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_win_set_buf(0, panel)
				vim.bo[panel].buftype = "nofile"
				require("lualine").refresh({ force = true })
			]])
		end,
		post_once = child.stop,
	},
})

T["first file opened from a panel has a statusline before queued refreshes"] = function()
	child.lua([[
		local buffer = vim.api.nvim_create_buf(false, false)
		vim.api.nvim_buf_set_name(buffer, "/outside/first-open.md")
		vim.api.nvim_win_set_buf(editor, buffer)
		vim.api.nvim_set_current_win(editor)
		-- Inspect in the same turn, before lualine's timer can hide a blank frame.
		immediate = vim.wo.statusline
	]])
	assert.same(true, child.lua_get("immediate:find('VISIBLE', 1, true) ~= nil"))
end

T["file opened while retaining panel focus also refreshes immediately"] = function()
	child.lua([[
		vim.api.nvim_win_call(editor, function()
			vim.cmd.edit("/outside/new-file.md")
		end)
		immediate = vim.wo[editor].statusline
	]])
	assert.same(true, child.lua_get("immediate:find('VISIBLE', 1, true) ~= nil"))
end

T["panel remembers the last focused file window without a separate tracker"] = function()
	child.lua([[
		vim.api.nvim_set_current_win(editor)
		vim.api.nvim_buf_set_name(0, "/outside/older.md")
		vim.cmd.vsplit()
		vim.cmd.edit("/outside/recent.md")
		vim.api.nvim_set_current_win(panel_win)
		immediate = vim.wo.statusline
	]])
	assert.same(true, child.lua_get("immediate:find('recent.md', 1, true) ~= nil"))
	child.lua([[
		vim.api.nvim_set_current_win(editor)
		vim.api.nvim_set_current_win(panel_win)
		immediate = vim.wo.statusline
	]])
	assert.same(true, child.lua_get("immediate:find('older.md', 1, true) ~= nil"))
end

return T
