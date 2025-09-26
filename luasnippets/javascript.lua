---@diagnostic disable: undefined-global

local M = {}

-- local same = require('my.utils.snippets').same

local preferred_quote = require('my.parameters').preferred_quote

local function concat(t1, t2)
  for i = 1, #t2 do
    t1[#t1 + 1] = t2[i]
  end
  return t1
end

local function to_same(args)
  return args[1][1]
end

--  TODO: case, try, class, default, else, extends, import, with

for _, keyword in ipairs {
  'break',
  'continue',
  'delete ',
  'export ',
  'extends ',
  'instanceof ',
  'return ',
  'super',
  'super.',
  'this',
  'throw ',
  'typeof ',
  'void',
  'yield ',
} do
  table.insert(M, s(keyword, { t(keyword) }))
end

table.insert(
  M,
  s(
    '.map',
    fmt(
      '.map(([]) => [])',
      { i(1, 'x'), f(to_same, { 1 }) },
      { delimiters = '[]' }
    )
  )
)
table.insert(
  M,
  s(
    'filter',
    fmt(
      '.filter(([]) => [])',
      { i(1, 'x'), f(to_same, { 1 }) },
      { delimiters = '[]' }
    )
  )
)
table.insert(
  M,
  s(
    'object map',
    fmt(
      [[
      const <> = Object.fromEntries(
        Object.entries(<>).map(([<>, <>]) =<> { <>return [<>, <>] }),
      )
    ]],
      {
        i(1, 'target'),
        i(2, 'source'),
        i(3, 'key'),
        i(4, 'value'),
        t '>',
        i(5),
        f(to_same, { 3 }),
        f(to_same, { 4 }),
      },
      { delimiters = '<>' }
    )
  )
)

table.insert(
  M,
  s(
    'const',
    fmt('const [] = []', { i(1, 'name'), i(2, '0') }, { delimiters = '[]' })
  )
)

table.insert(
  M,
  s(
    'let',
    fmt('let [] = []', { i(1, 'name'), i(2, '0') }, { delimiters = '[]' })
  )
)

table.insert(
  M,
  s(
    'for of',
    fmt(
      [[
      for (const [] of []) {
        []
      }
    ]],
      { i(1, 'name'), i(2, 'iterator'), i(3, '') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'for c',
    fmt(
      [[
      for ([]; []; []) {
        []
      }
    ]],
      { i(1, 'let i = 0'), i(2, 'i < 10'), i(3, 'i++'), i(4, '') },
      { delimiters = '[]' }
    )
  )
)

-- FIXME: indentation
table.insert(
  M,
  s('else', {
    c(1, {
      sn(1, { t { '} else {', '\t' }, i(1, '') }),
      sn(1, { t '} else if (', i(1, 'true'), t { ') {', '\t' }, i(2, '') }),
    }),
  })
)

table.insert(
  M,
  s('else if', {
    c(1, {
      sn(1, { t '} else if (', i(1, 'true'), t { ') {', '\t' }, i(2, '') }),
      sn(1, { t { '} else {', '\t' }, i(1, '') }),
    }),
  })
)

table.insert(
  M,
  s(
    'async funtion',
    fmt(
      [[
        async function []([]) {
          []
        }
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

table.insert(M, s('export', fmt('export ', {}, { delimiters = '[]' })))
table.insert(
  M,
  s('export default', fmt('export default ', {}, { delimiters = '[]' }))
)

table.insert(
  M,
  s(
    'dot filter',
    fmt(
      '.filter(([]) => [])',
      { i(1, 'identifier'), i(2, 'true') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'dot map',
    fmt(
      '.map(([]) => [][])',
      { i(1, 'identifier'), same(1), i(0) },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'lambda',
    fmt('([]) => []', { i(1, '_params'), i(2, '0') }, { delimiters = '[]' })
  )
)

table.insert(
  M,
  s(
    'lambda async',
    fmt(
      'async ([]) => []',
      { i(1, '_params'), i(2, '0') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'lambda return',
    fmt(
      [[
      ([]) => {
        return []
      }
    ]],
      { i(1, '_params'), i(2, '0') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'lambda async return',
    fmt(
      [[
      async ([]) => {
        return []
      }
    ]],
      { i(1, '_params'), i(2, '0') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'switch',
    fmt(
      [[
        switch ([]) {
          case []: 
            []
            break
          default: 
            []
        }
      ]],
      { i(1, 'expr'), i(2, 'value'), i(3, ''), i(4, '') },
      {
        delimiters = '[]',
      }
    )
  )
)

table.insert(
  M,
  s(
    'case',
    fmt(
      [[
        case []: 
          []
          break
      ]],
      { i(1, 'value'), i(2, '') },
      {
        delimiters = '[]',
      }
    )
  )
)

table.insert(
  M,
  s(
    'default',
    fmt(
      [[
        default: 
          []
      ]],
      { i(1, '') },
      {
        delimiters = '[]',
      }
    )
  )
)

table.insert(
  M,
  s(
    'try',
    fmt(
      [[
        try {
          []
        } catch (err) {
          []
        }
      ]],
      { i(1, ''), i(2, '') },
      {
        delimiters = '[]',
      }
    )
  )
)

table.insert(
  M,
  s(
    'rethrow',
    fmt(
      [[
        try {
          []
        } catch (error) {
          if (error.code !== "[]") throw error[]
        }
      ]],
      { i(1, ''), i(2, 'ENOENT'), i(3, '') },
      {
        delimiters = '[]',
      }
    )
  )
)

-- Testing
table.insert(
  M,
  s(
    'tst',
    fmt(
      [[
        test("[]", () => {
          []
        })
      ]],
      { i(1, 'description'), i(2, '') },
      { delimiters = '[]' }
    )
  )
)
table.insert(
  M,
  s(
    'itt',
    fmt(
      [[
        it("[]", () => {
          []
        })
      ]],
      { i(1, 'description'), i(2, '') },
      { delimiters = '[]' }
    )
  )
)

--TODO: default from filename
table.insert(
  M,
  s(
    'dsc',
    fmt(
      [[
        describe("[]", () => {
          []
        })
      ]],
      { i(1, 'description'), i(2, '') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'expect toThrow',
    fmt(
      [[
        expect(() => { [] }).toThrow[]([])
      ]],
      { i(1, '/* statement */'), i(2, ''), i(3, '') },
      { delimiters = '[]' }
    )
  )
)

table.insert(
  M,
  s(
    'expect toThrowError',
    fmt(
      [[
        expect(() => { [] }).toThrowError[]([])
      ]],
      { i(1, ''), i(2, ''), i(3, '') },
      { delimiters = '[]' }
    )
  )
)

-- assertions
for _, name in ipairs { 'toEqual', 'toBe', 'toContain', 'toMatch', 'toBeTruthy', 'toBeFalsy' } do
  table.insert(
    M,
    s(
      'expect' .. name,
      fmt(
        'expect([]).[]([])',
        { i(1, 'actual'), t(name), i(2, 'expected') },
        { delimiters = '[]' }
      )
    )
  )
end

-- property testing

table.insert(
  M,
  s(
    'fcassert',
    fmt(
      [[
        fc.assert(fc.property([], ([]) => {[]}))
      ]],
      {
        i(1, ''),
        i(2, ''),
        i(3, ''),
      },
      { delimiters = '[]' }
    )
  )
)

require('plugins.flies.utils').add_snips(M, 'javascript')

return M
