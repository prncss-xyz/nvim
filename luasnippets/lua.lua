---@diagnostic disable: undefined-global

local M = {}

table.insert(
  M,
  s(
    'module',
    fmt(
      [[
        local M = {}
        
        <>

        return M
      ]],
      {
        i(1, ''),
      },
      {
        delimiters = '<>',
      }
    )
  )
)

return M
