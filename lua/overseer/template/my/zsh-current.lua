return {
  name = 'zsh, current file',
  builder = function()
    return {
      cmd = { 'zsh' },
      cwd = vim.fn.expand '%:p:h',
      args = {},
      components = { 'default' },
      metadata = {},
    }
  end,
}
