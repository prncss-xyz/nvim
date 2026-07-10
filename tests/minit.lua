#!/usr/bin/env -S nvim -l

local root = vim.uv.cwd()
local test_path = vim.fs.joinpath(root, ".tests", "mini.test")

if not vim.uv.fs_stat(test_path) then
	local output = vim.fn.system({
		"git",
		"clone",
		"--depth=1",
		"--branch=stable",
		"https://github.com/nvim-mini/mini.test.git",
		test_path,
	})
	assert(vim.v.shell_error == 0, output)
end

vim.opt.rtp:prepend(root)
vim.opt.rtp:prepend(test_path)

local MiniTest = require("mini.test")
local lua_assert = assert

MiniTest.setup({
	collect = {
		find_files = function()
			local files = vim.tbl_filter(function(path)
				return path:match("_spec%.lua$") ~= nil
			end, _G.arg)
			return #files > 0 and files or vim.fn.globpath("tests", "**/*_spec.lua", true, true)
		end,
	},
})

_G.assert = setmetatable({
	same = MiniTest.expect.equality,
}, {
	__call = function(_, ...)
		return lua_assert(...)
	end,
})

MiniTest.run()
