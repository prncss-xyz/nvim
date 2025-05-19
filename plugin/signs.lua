-- FIXME: not working in foot terminal

vim.fn.sign_define("DiagnosticSignError", { text = " ", texthl = "diagnosticvirtualtextError" })
vim.fn.sign_define("DiagnosticSignWarn", { text = " ", texthl = "diagnosticvirtualtextWarn" })
vim.fn.sign_define("DiagnosticSignHint", { text = "", texthl = "diagnosticvirtualtextHint" })
vim.fn.sign_define("DiagnosticSignInfo", { text = " ", texthl = "diagnosticvirtualtextInfo" })
vim.fn.sign_define("DapBreakpoint", { text = "ﱣ", texthl = "DiagnosticError", linehl = "", numhl = "" })
vim.fn.sign_define("DapStopped", { text = "", texthl = "DiagnosticHint", linehl = "", numhl = "" })
