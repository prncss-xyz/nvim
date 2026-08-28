---@diagnostic disable: undefined-global

local M = {}

table.insert(
	M,
	s(
		"local stub",
		fmt(
			[[
        local function <>(<>)
          <>
        end
      ]],
			{
				i(1, "name"),
				i(2, ""),
				i(3, "error('not implemented')"),
			},
			{
				delimiters = "<>",
			}
		)
	)
)

table.insert(
	M,
	s(
		"stub",
		fmt(
			[[
        function M.<>(<>)
          <>
        end
      ]],
			{
				i(1, "name"),
				i(2, ""),
				i(3, "error('not implemented')"),
			},
			{
				delimiters = "<>",
			}
		)
	)
)

return M
