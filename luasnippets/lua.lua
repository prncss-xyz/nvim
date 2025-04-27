---@diagnostic disable: undefined-global

local M = {}

table.insert(
  M,
  s(
    'else',
    fmt(
      [[
        else
          []
      ]],
      {
        i(1, ''),
      },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'local assignement',
    fmt('local [] = []', {
      i(1, 'name'),
      i(2, '0'),
    }, { delimiters = '[]' })
  )
)

table.insert(
  M,
  s(
    'local require',
    fmt('local [] = require "[]"', {
      i(1, 'name'),
      i(2, 'module'),
    }, { delimiters = '[]' })
  )
)

table.insert(
  M,
  s(
    'local function',
    fmt(
      [[
      local function []([]) 
        [] 
      end
      ]],
      {
        i(1, 'name'),
        i(2, ''),
        i(3, ''),
      },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'repeat until',
    fmt(
      [[
        repeat
          []
        until []
      ]],
      {
        i(1, ''),
        i(2, 'false'),
      },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'for ',
    fmt(
      [[
        for [] in [] do
          []
        end
      ]],
      {
        i(1, 'v'),
        i(2, 'iterator'),
        i(3, ''),
      },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'for pairs',
    fmt(
      [[
        for [], [] in pairs([]) do
          []
        end
      ]],
      {
        i(1, 'k'),
        i(2, 'v'),
        i(3, 'table_'), -- to makes sure lsp flags an undefined variable, and not unintentionnaly use builtin table
        i(4, ''),
      },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'for ipairs',
    fmt(
      [[
        for [], [] in ipairs([]) do
          []
        end
      ]],
      {
        i(1, 'i'),
        i(2, 'v'),
        i(3, 'list'),
        i(4, ''),
      },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'for line',
    fmt(
      [[
        f = io.open([])
        while true do
          local line = f:read()
          if line == nil then 
            break 
          end
          []
        end
      ]],
      {
        i(1, 'filepath'),
        i(2, ''),
      },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'forc',
    fmt(
      [[
        for [] = [], []  do
          []
        end
      ]],
      {
        i(1, 'i'),
        i(2, '1'),
        i(3, '10'),
        i(4, ''),
      },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'for char',
    fmt(
      [[
        for [] in str:gmatch '.' do
         []
        end
      ]],
      {
        i(1, 'char'),
        i(2, ''),
      },
      { delimiters = '[]' }
    )
  )
)

-- luasnip:
table.insert(
  M,
  s(
    'snippet',
    fmt(
      [[
        table.insert(
          M,
          s(
            '<>',
            fmt(
              <>
                <>
              <>,
              {<>},
              { delimiters = '<>' }
            )
          )
        )
      ]],
      {
        i(1, 'trigger'),
        t '[[',
        i(3, ''),
        t ']]',
        i(4, ''),
        i(2, '[]'),
      },
      { delimiters = '<>' }
    )
  )
)

-- busted:

for _, name in ipairs {
  'setup',
  'teardown',
  'lazy_setup',
  'lazy_teardown',
  'strict_setup',
  'strict_teardown',
  'before_each',
  'after_each',
  'finally',
} do
  table.insert(
    M,
    s(
      name,
      fmt(
        [[
        [](function()
          []
        end)
      ]],
        { t(name), i(1, '') },
        { delimiters = '[]' }
      )
    )
  )
end

table.insert(
  M,
  s(
    'pending',
    fmt(
      [[pending("[]")]],
      { i(1, 'description') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'describe',
    fmt(
      [[
        describe("[]", function()
          []
        end)
      ]],
      { i(1, 'description'), i(2, '') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'it',
    fmt(
      [[
        it("[]", function()
          []
        end)
      ]],
      { i(1, 'description'), i(2, '') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'test',
    fmt(
      [[
        describe("[]", function()
          it("[]", function())
            []
          end)
        end)
      ]],
      { i(1, 'description'), i(2, 'description'), i(2, '') },
      { delimiters = '[]' }
    )
  )
)

-- busted: assertions
for _, name in ipairs { 'same', 'equals' } do
  table.insert(
    M,
    s(
      name,
      fmt(
        'assert.are.[]([], [])',
        { t(name), i(1, 'expected'), i(2, 'passed') },
        { delimiters = '[]' }
      )
    )
  )
  table.insert(
    M,
    s(
      'not ' .. name,
      fmt(
        'assert.are_not.[]([], [])',
        { t(name), i(1, 'expected'), i(2, 'passed') },
        { delimiters = '[]' }
      )
    )
  )
end

for _, name in ipairs { 'truthy', 'falsy', 'not_true', 'not_false' } do
  table.insert(
    M,
    s(
      name,
      fmt(
        'assert.is.[]([])',
        { t(name), i(2, 'passed') },
        { delimiters = '[]' }
      )
    )
  )
end

for _, name in ipairs { 'is_true', 'is_false' } do
  table.insert(
    M,
    s(
      name,
      fmt('assert.[]([])', { t(name), i(1, 'passed') }, { delimiters = '[]' })
    )
  )
end

table.insert(
  M,
  s(
    'has_error',
    fmt(
      [[
        assert.has_error(function()
          []
        end)
      ]],
      { i(1, '') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'has_no.errors',
    fmt(
      [[
        assert.has_no.errors(function()
          []
        end)
      ]],
      { i(1, '') },
      { delimiters = '[]' }
    )
  )
)

-- cheat:

table.insert(
  M,
  s(
    'iterate over characters of string',
    fmt(
      [[        
        for {} = {}, #{} do
          local {} = {}:sub({}, {})
          {}
        end
      ]],
      {
        i(1, 'i'),
        i(2, '1'),
        i(3, 'str'),
        i(4, 'char'),
        same(3),
        same(1),
        same(1),
        i(4, '--TODO:'),
      },
      { delimiters = '{}' }
    )
  )
)

require('plugins.flies.utils').add_snips(M, 'lua')

return M
