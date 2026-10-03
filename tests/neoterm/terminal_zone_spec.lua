local MiniTest = require("mini.test")
local T = MiniTest.new_set()

T["terminal directory change only visits a directory with an open file buffer"] = function()
	local modules = {
		"toggleterm.terminal",
		"neoterm.terms.attach_term",
		"neoterm.terms.window",
		"neoterm.helpers.ensure_dir",
		"neoterm.rooter",
		"neoterm.terms.artifacts.cwd",
		"neoterm.terms.create_term",
	}
	local original = {}
	for _, name in ipairs(modules) do
		original[name] = package.loaded[name]
	end
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	local ensured = 0
	package.loaded["toggleterm.terminal"] = { Terminal = { new = function() return {} end } }
	package.loaded["neoterm.terms.attach_term"] = { attach_term = function() end }
	package.loaded["neoterm.terms.window"] = { is_visible = function() return false end }
	package.loaded["neoterm.helpers.ensure_dir"] = { ensure_dir = function() ensured = ensured + 1 end }
	package.loaded["neoterm.rooter"] = { project_dir = function(path) return path end }
	package.loaded["neoterm.terms.artifacts.cwd"] = { resolve = function() return nil end }
	package.loaded["neoterm.terms.create_term"] = nil
	local ok, err = pcall(function()
		local term = require("neoterm.terms.create_term"):new({}, function() end)
		local osc = "\27]7;file://localhost" .. dir .. "\7"
		term:handle_osc(0, osc)
		vim.wait(100, function() return term.cwd == dir end)
		vim.wait(50)
		assert.same(0, ensured)
		local buf = vim.api.nvim_create_buf(true, false)
		vim.api.nvim_buf_set_name(buf, dir .. "/file.txt")
		term:handle_osc(0, osc)
		vim.wait(100, function() return ensured > 0 end)
		assert.same(1, ensured)
		vim.api.nvim_buf_delete(buf, { force = true })
	end)
	for _, name in ipairs(modules) do
		package.loaded[name] = original[name]
	end
	vim.fn.delete(dir, "rf")
	if not ok then error(err) end
end

return T
