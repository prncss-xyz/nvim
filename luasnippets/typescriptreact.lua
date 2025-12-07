---@diagnostic disable: undefined-global

local M = {}

local function to_same(args)
  return args[1][1]
end

local function to_upper(args)
  return args[1][1]:gsub("^%l", string.upper)
end

table.insert(
  M,
  s(
    'component',
    fmt(
      [[
        function []({[]}: {[]}) {
          []
        }
      ]],
      {
        i(1, ''),
        i(3, ''),
        i(2, ''),
        i(4, ''),
      },
      {
        delimiters = '[]',
      }
    )
  )
)

table.insert(
  M,
  s(
    'export component',
    fmt(
      [[
        export function []({[]}: {[]}) {
          []
        }
      ]],
      {
        i(1, ''),
        i(3, ''),
        i(2, ''),
        i(4, ''),
      },
      {
        delimiters = '[]',
      }
    )
  )
)

return M
