-- currently not needed, using lualine builtin

return function()
  if not package.loaded['overseer'] then
    return ''
  end
  local STATUS = require('overseer.constants').STATUS
  local symbols = {
    [STATUS.FAILURE] = ' ',
    [STATUS.CANCELED] = ' ',
    [STATUS.SUCCESS] = ' ',
    [STATUS.RUNNING] = '省',
  }
  local tasks = require('overseer.task_list').list_tasks {}
  local tasks_by_status = require('overseer.util').tbl_group_by(tasks, 'status')
  local pieces = {}
  for _, status in ipairs(STATUS.values) do
    local status_tasks = tasks_by_status[status]
    if symbols[status] and status_tasks then
      table.insert(
        pieces,
        string.format('%s %s', symbols[status], #status_tasks)
      )
    end
  end
  if #pieces > 0 then
    return table.concat(pieces, ' ')
  end
  return ''
end
