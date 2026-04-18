---@diagnostic disable: undefined-global

local M = {}

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
