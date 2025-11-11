local M = {}

local not_vscode = require("my.conds").not_vscode

local ls = require("luasnip")
local i = ls.insert_node
local f = ls.function_node
local contents = ls.function_node(function(_, snip)
	return snip.captures.contents
end, {})
local fmt = require("luasnip.extras.fmt").fmt

M.B = {
	left = "(",
	right = ")",
	snip = not_vscode({
		all = fmt("([][][])", {
			i(1, ""),
			contents,
			i(2, ""),
		}, { delimiters = "[]" }),
	}),
}

M.b = {
	left = "{",
	right = "}",
	snip = not_vscode({
		all = fmt("{[][][]}", {
      i(1, ""),
			contents,
			i(2, ""),
		}, { delimiters = "[]" }),
	}),
}

M.i = {
	snip = not_vscode({
		javascript = fmt(
			[[
	          if ([]) {
	            [][]
	          }
	        ]],
			{
				i(1, "true"),
				contents,
				i(2, ""),
			},
			{ delimiters = "[]" }
		),
		lua = fmt(
			[[
	          if [] then
	            [][]
	          end
	        ]],
			{
				i(1, "true"),
				contents,
				i(2, ""),
			},
			{ delimiters = "[]" }
		),
	}),
}

M.k = {
	snip = not_vscode({
		all = fmt([[<>(<><><>) ]], {
			i(1, "name"),
			i(2, ""),
			contents,
			i(3, ""),
		}, { delimiters = "<>" }),
	}),
}

M.l = {
	snip = not_vscode({
		javascript = fmt(
			[[
	          while ([]) {
	            [][][]
	          }
	        ]],
			{
				i(1, "true"),
				i(2, ""),
				contents,
				i(3, ""),
			},
			{ delimiters = "[]" }
		),
		lua = fmt(
			[[
	          while [] do
	            [][][]
	          end
	        ]],
			{
				i(1, "true"),
				i(2, ""),
				contents,
				i(3, ""),
			},
			{ delimiters = "[]" }
		),
	}),
}

M.Q = {
	left = '"',
	right = '"',
	snip = not_vscode({
		all = fmt('"[][][]"', {
			i(1, ""),
			contents,
			i(2, ""),
		}, { delimiters = "[]" }),
	}),
}

M.q = {
	left = "`",
	right = "`",
	snip = not_vscode({
		all = fmt("`[][][]`", {
			i(1, ""),
			contents,
			i(2, ""),
		}, { delimiters = "[]" }),
	}),
}

M.y = {
	snip = not_vscode({
		javascript = fmt(
			[[
	          function []([]) {
	            [][]
	          }
	        ]],
			{
				i(1, "name"),
				i(2, ""),
				contents,
				i(3, ""),
			},
			{ delimiters = "[]" }
		),
		lua = fmt(
			[[
	          function []([])
	            [][]
	          end
	        ]],
			{
				i(1, "name"),
				i(2, ""),
				contents,
				i(3, ""),
			},
			{ delimiters = "[]" }
		),
	}),
}

local function to_tag(args)
	return args[1][1]:match("([%w%.]+)") or ""
end

M.t = {
	left = "<>",
	right = "</>",
	snip = not_vscode({
		all = fmt(
			[[
	          <[]>
	            [][][]
	          </[]>
	        ]],
			{
				i(1, ""),
				i(2, ""),
				contents,
				i(3, ""),
				f(to_tag, { 1 }),
			},
			{ delimiters = "[]" }
		),
	}),
}

-- TODO:
M.pw = {
	left = " ",
	snip = not_vscode({
		all = fmt("[] []", {
			i(1, ""),
			contents,
		}, { delimiters = "[]" }),
	}),
}

M.w = {
	left = " ",
	snip = not_vscode({
		all = fmt("[] []", {
			contents,
			i(1, ""),
		}, { delimiters = "[]" }),
	}),
}

M[","] = {
	left = ", ",
	snip = not_vscode({
		all = fmt("[], []", {
			contents,
			i(1, ""),
		}, { delimiters = "[]" }),
	}),
}

return M
