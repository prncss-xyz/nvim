local M = {}

---Send a system notification or fallback to vim.notify
---@param msg string Notification message
---@param opts? { title?: string }
function M.notify(msg, opts)
  opts = opts or {}
  local title = opts.title or "Neovim"

  local notify_cmd
  if vim.fn.executable("osascript") == 1 then
    notify_cmd = { "osascript", "-e", string.format('display notification "%s" with title "%s"', msg, title) }
  elseif vim.fn.executable("notify-send") == 1 then
    notify_cmd = { "notify-send", title, msg }
  end

  if notify_cmd then
    vim.fn.jobstart(notify_cmd, { detach = true })
  else
    vim.notify(msg)
  end
end

return M
