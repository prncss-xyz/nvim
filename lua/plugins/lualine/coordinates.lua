local function coordinates()
  local bt = vim.api.nvim_buf_get_option(0, 'buftype')
  if bt ~= '' then
    return ''
  end
  local line = vim.fn.line '.'
  local column = vim.fn.col '.'
  local line_count = vim.fn.line '$'
  return string.format(' %3d:%02d %d ', line, column, line_count)
end

return coordinates
