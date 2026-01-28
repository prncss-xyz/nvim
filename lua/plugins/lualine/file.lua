local unknown_icon = ''
-- local skipLock = { 'Outline', 'Trouble', 'LuaTree', 'dbui', 'help' }
local skip_lock = {}

local user_icons = {}

-- TODO: find icons for relevant buffer types
local buf_icon = {
  help = '  ',
  Trouble = '  ',
  Outline = '  ',
  DiffviewFiles = '  ',
  ['neo-tree'] = '  ',
}

local function get_file_icon()
  local icon = ''
  if vim.fn.exists '*WebDevIconsGetFileTypeSymbol' == 1 then
    icon = vim.fn.WebDevIconsGetFileTypeSymbol()
    return icon .. ' '
  end
  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if not ok then
    print "No icon plugin found. Please install 'kyazdani42/nvim-web-devicons'"
    return ''
  end
  local f_name = vim.fn.expand '%:t'
  local f_extension
  vim.fn.expand '%:e'
  icon = devicons.get_icon(f_name, f_extension)
  if icon == nil then
    if user_icons[vim.bo.filetype] ~= nil then
      icon = user_icons[vim.bo.filetype][2]
    elseif user_icons[f_extension] ~= nil then
      icon = user_icons[f_extension][2]
    else
      icon = unknown_icon
    end
  end
  return icon .. '  '
end

local function get_buffer_type_icon()
  return buf_icon[vim.bo.filetype]
end

local function trouble_mode()
  local mode = require('trouble.config').options.mode
  if mode == 'workspace_diagnostics' then
    return 'Workspace diagnostics'
  end
  if mode == 'document_diagnostics' then
    return 'Document diagnostics'
  end
  if mode == 'references' then
    return 'References'
  end
  if mode == 'definitions' then
    return 'Definitions'
  end
  if mode == 'todo' then
    return 'Todo'
  end
  return mode
end

local function get_displayed_name()
  if vim.bo.filetype == 'Trouble' then
    return trouble_mode()
  end
  if vim.bo.buftype == 'nofile' then
    return vim.bo.filetype
  end
  local file = vim.fn.expand '%:p'
  local cwd = vim.fn.getcwd()
  if file:find(cwd, 1, true) then
    return file:sub(#cwd + 2)
  end
  local home = vim.fn.getenv 'HOME'
  if file:find(home, 1, true) then
    return '~/' .. file:sub(#home + 2)
  end
  return file
end

local function get_name_iconified()
  local res = ''
  res = res .. get_displayed_name()
  res = res .. ' '
  res = res .. (get_buffer_type_icon() or get_file_icon())
  return res
end

local function get_diagnostic()
  local res = {}
  for _, diag in ipairs(vim.diagnostic.get(0, nil)) do
    res[diag.severity] = (res[diag.severity] or 0) + 1
  end
  return res
end

local function get_status_icons()
  -- modified
  local file = vim.fn.expand '%:t'
  local icons = {}
  if vim.fn.empty(file) ~= 1 and vim.bo.modifiable and vim.bo.modified then
    table.insert(icons, '')
  end
  -- read only
  if
    vim.bo.buftype ~= 'nofile'
    -- and vim.fn.index(skipLock, vim.bo.filetype) ~= -1
    and vim.tbl_contains(skip_lock, vim.bo.filetype)
    and vim.bo.readonly == true
  then
    table.insert(icons, '')
  end

  -- diagnostics
  local diagnostic = get_diagnostic()
  if diagnostic[vim.diagnostic.severity.ERROR] then
    table.insert(icons, '')
  end
  if diagnostic[vim.diagnostic.severity.WARN] then
    table.insert(icons, '')
  end
  local icons_string = table.concat(icons, ' ')
  if #icons > 0 then
    icons_string = '  ' .. icons_string
  end
  return icons_string
end

return function()
  local str = ''
  str = str .. get_name_iconified() .. ' '
  --[[ str = str .. get_displayed_name() ]]
  str = str .. get_status_icons() .. '  '
  return str
end
