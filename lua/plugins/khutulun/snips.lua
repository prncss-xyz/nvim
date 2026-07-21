local ls = require("luasnip")
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

return {
	{
		pattern = "%.lua$",
		fn = function()
			return fmt(
				[[local M = {}

[]

return M]],
				{
					i(1, ""),
				},
				{ delimiters = "[]" }
			)
		end,
	},
	{
		pattern = "^README.md$",
		fn = function()
			local cwd = vim.fn.getcwd()
			local title = vim.fs.basename(cwd)
			local branch = vim.trim(vim.fn.system("git branch --show-current 2>/dev/null"))
			if title == branch then
				title = vim.fs.basename(vim.fs.dirname(cwd))
			end
			title = title:gsub("^%l", string.upper)
			return fmt(
				[[# []

[]
]],
				{
					i(1, title),
					i(2, ""),
				},
				{ delimiters = "[]" }
			)
		end,
	},
	{
		pattern = "%.md$",
		fn = function()
			local file = vim.api.nvim_buf_get_name(0)
			local basename = vim.fs.basename(file):gsub("%.md$", "")
			local title = (basename == "index" or basename == "README") and vim.fs.basename(vim.fs.dirname(file))
				or basename
			title = title:gsub("^%l", string.upper)
			return fmt(
				[[# []

[]
]],
				{
					i(1, title),
					i(2, ""),
				},
				{ delimiters = "[]" }
			)
		end,
	},
	{
		pattern = "^LICENSE$",
		fn = function()
			return fmt(
				[[MIT License

Copyright (c) [] []

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]],
				{
					i(1, tostring(os.date("%Y"))),
					i(2, (vim.fn.system("git config --global user.name"):gsub("\n", ""))),
				},
				{ delimiters = "[]" }
			)
		end,
	},
}
