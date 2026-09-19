local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["Pi spinner updates terminal state through the real buffer attachment"] = function()
	child.lua([=[
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["neoterm.config"] = { on_status = function() end }
		package.loaded["neoterm.terms.pseudo_terminal"] = { create = function() return {} end }
		package.loaded["neoterm.terms.window"] = { is_in_view = function() return false end }
		package.loaded["neoterm.terms.git"] = { ensure_worktree = function(_, cb) cb(true) end }
		package.loaded["neoterm.terms.get_commands"] = { get_commands = function(_, _, cb) cb({}) end }
		package.loaded["neoterm.terms.create_term"] = {
			new = function(_, opts, send)
				buf = vim.api.nvim_create_buf(false, true)
				channel = vim.api.nvim_open_term(buf, {})
				local term = { bufnr = buf, is_in_view = function() return false end }
				require("neoterm.terms.attach_term").attach_term(term, send, opts.screen_manifest)
				return term
			end,
		}
		terms = require("neoterm.terms")
		terms.prepare({ key = "p", cmd = "p", cwd = "/tmp" })
		vim.api.nvim_chan_send(channel, "\r\n ⠏ Working   \r\n\r\n────────────────\r\n\r\n────────────────\r\nfooter")
		working = vim.wait(1000, function() return terms.has_working() end)
	]=])
	assert.same(true, child.lua_get("working"))
	child.lua([=[
		vim.api.nvim_chan_send(channel, "\27[2J\27[HReady\r\n")
		idle = vim.wait(1500, function() return not terms.has_working() end)
	]=])
	assert.same(true, child.lua_get("idle"))
end

return T
