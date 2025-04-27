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
    'set Props Type',
    fmt(
      [[{}: {}; set{}: Disaptch<SetStateAction<{}>>; ]],
      {
        i(1, ''),
        i(2, ''),
        f(to_upper, {1}),
        f(to_same, {2}),
      },
      {
        delimiters = '{}',
      }
    )
  )
)

table.insert(
  M,
  s(
    'component',
    fmt(
      [[
        function []({[] children }: {[] children: ReactNode }) {
          return []
        }
      ]],
      {
        i(1, 'Name'),
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
        export function []({[] children }: {[] children: ReactNode }) {
          return []
        }
      ]],
      {
        i(1, 'Name'),
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

require('plugins.flies.utils').add_snips(M, 'typescriptreact')

return M
