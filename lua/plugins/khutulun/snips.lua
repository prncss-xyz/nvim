local M = {}

local ls = require("luasnip")
local i = ls.insert_node
local fmt = require("luasnip.extras.fmt").fmt

M[".+%.lua"] = function()
	return fmt(
		[[local M = {}

[]

return M]],
		{
			i(1, ""),
		},
		{ delimiters = "[]" }
	)
end

M["LICENSE"] = function()
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
      i(1, "Juliette Lamarche"),
    },
		{ delimiters = "[]" }
	)
end

return M
