---@diagnostic disable: undefined-global

local M = {}

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

require("plugins.flies.utils").add_snips(M, "markdown")

return M
