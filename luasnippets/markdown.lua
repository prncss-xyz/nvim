---@diagnostic disable: undefined-global

local M = {}

table.insert(
	M,
	s(
		"link",
		fmt("[{}]({})", {
			i(1, "text"),
			i(2, "url"),
		}, { delimiters = "{}" })
	)
)

table.insert(M, s("quote", fmt("`{}`", { i(1, "") }, { delimiters = "{}" })))
table.insert(M, s("img", fmt("![{}]({})", { i(1, "alt"), i(2, "url") }, { delimiters = "{}" })))
table.insert(
	M,
	s(
		"codeblock",
		fmt(
			[[
        ```{}
        {}
        ```
      ]],
			{
				i(1, "lang"),
				i(2, "code"),
			},
			{ delimiters = "{}" }
		)
	)
)

for _, lang in ipairs({
	"lua",
	"haskell",
	"go",
	"bash",
	"c",
	"cpp",
	"javascript",
	"typescript",
	"jsx",
	"tsx",
	"json",
	"svg",
	"mermaid",
	"fish",
}) do
	table.insert(
		M,
		s(
			lang,
			fmt(
				[[
        ```[]
        []
        ```
      ]],
				{
					t(lang),
					i(1, ""),
				},
				{ delimiters = "[]" }
			)
		)
	)
end

return M
