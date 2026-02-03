---@diagnostic disable: undefined-global

local M = {}

table.insert(M, s("tsk", fmt("- [ ] ", {}, { delimiters = "{}" })))

table.insert(
	M,
	s(
		"lnk",
		fmt("[{}]({})", {
			i(1, ""),
			i(2, ""),
		}, { delimiters = "{}" })
	)
)

table.insert(
	M,
	s(
		"wlk",
		fmt("[[{}]]", {
			i(1, ""),
		}, { delimiters = "{}" })
	)
)

table.insert(M, s("img", fmt("![{}]({})", { i(1, ""), i(2, "") }, { delimiters = "{}" })))
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
				i(1, ""),
				i(2, ""),
			},
			{ delimiters = "{}" }
		)
	)
)

for _, lang in ipairs({
	"lua",
	"haskell",
	"go",
	"sh",
	"c",
	"cpp",
	"js",
	"ts",
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
