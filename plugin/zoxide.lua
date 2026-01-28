vim.api.nvim_create_autocmd("DirChanged", {
  desc = "Register directory changes in zoxide",
  callback = function(ev)
    vim.fn.jobstart({ "zoxide", "add", ev.file }, { detach = true })
  end,
})
