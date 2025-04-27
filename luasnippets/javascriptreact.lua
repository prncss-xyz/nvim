---@diagnostic disable: undefined-global

local M = {}

table.insert(
  M,
  s(
    'useCallback',
    fmt(
      [[
        const {} = useCallback(({}) => {}, [])
      ]],
      {
        i(1, ''),
        i(2, ''),
        i(2, ''),
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
    'useEffect',
    fmt(
      [[
        useEffect(() => {}, [])
      ]],
      {
        i(1, ''),
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
    'useMemo',
    fmt(
      [[
        const {} = useMemo(() => {}, [])
      ]],
      {
        i(1, ''),
        i(2, ''),
      },
      {
        delimiters = '{}',
      }
    )
  )
)

local function to_set(args)
  return 'set' .. args[1][1]:gsub('^%l', string.upper)
end

local function to_atom(args)
  return args[1][1] .. 'Atom'
end

table.insert(
  M,
  s(
    'set args',
    fmt([[<>={<>} <>={<>} ]], {
      i(1, ''),
      i(2, ''),
      f(to_set, { 1 }),
      f(to_set, { 2 }),
    }, {
      delimiters = '<>',
    })
  )
)

table.insert(
  M,
  s(
    'set props',
    fmt([[{}, {}, ]], {
      i(1, ''),
      f(to_set, { 1 }),
    }, {
      delimiters = '{}',
    })
  )
)

table.insert(
  M,
  s(
    'useState',
    fmt(
      [[
        const [{}, {}] = useState({});
      ]],
      {
        i(1, ''),
        f(to_set, { 1 }),
        i(2, ''),
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
    'useAtom',
    fmt(
      [[
        const [{}, {}] = useAtom({});
      ]],
      {
        i(1, ''),
        f(to_set, { 1 }),
        f(to_atom, { 1 }),
      },
      {
        delimiters = '{}',
      }
    )
  )
)

local preferred_quote = require('my.parameters').preferred_quote

local function quote(str)
  return quote_char .. str .. quote_char
end

local function quoted_filename()
  local source = vim.fn.expand '%:t'
  source = string.gsub(source, '(.test.tsx)', '')
  return string.format('%q', './' .. source)
end

local function raw_filename()
  local source = vim.fn.expand '%:t'
  source = string.gsub(source, '(.test.tsx)', '')
  return source
end

table.insert(
  M,
  s(
    'vitest-react',
    fmt(
      [[
        import { } from "@testing-library/react";
        import { [] } from [];

        describe([], () => {
          it("[]", () => {
            const { container } = render(
              <[] []/>
            );
            expect(container).toMatchSnapshot();
          });
        })
      ]],
      {
        p(raw_filename),
        p(quoted_filename),
        p(quoted_filename),
        i(1, 'should render correctly'),
        p(raw_filename),
        i(2, ''),
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
    'attribute',
    fmt('[]={[]} ', { i(1, 'name'), i(2, 'value') }, { delimiters = '[]' })
  )
)

-- NOTE: not useful, just keeping it as an exemple
if false then
  table.insert(
    M,
    s('__ test snapshot', {
      t { 'describe(' .. quote_char },
      i(1, 'description'),
      t { quote_char .. ', () => {' },
      t { '\tit(' .. quote_char },
      i(2, 'description'),
      t { quote_char .. ', () => {' },
      c(1, {
        sn(nil, {
          t '<',
          r(1, 'tag'),
          t ' ',
          r(2, 'attrs'),
          t ' />',
        }),
        sn(nil, {
          t '<',
          r(1, 'tag'),
          t ' ',
          r(2, 'attrs'),
          t ' >',
          r(3, 'children'),
          t '</',
          f(function(args)
            return args[1][1]
          end, { 1 }),
          t '>',
        }),
      }),
      t '}',
      t '}',
    }, {
      stored = {
        tag = i(1, 'tag'),
        attrs = i(1, ''),
        children = i(1, ''), -- probably useless
      },
    })
  )
end

return M
