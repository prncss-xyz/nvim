local reverse = require("my.parameters").reverse
local domain = require("my.parameters").domain
local edit = domain.edit
local move = domain.move
local web = domain.web
local win = domain.win
local directions = require("my.parameters").directions

vim.keymap.del("n", "gcc")
vim.keymap.set("n", "gra", "<nop>")
vim.keymap.set("x", "gra", "<nop>")
vim.keymap.set("n", "gri", "<nop>")
vim.keymap.set("n", "grn", "<nop>")
vim.keymap.set("n", "grr", "<nop>")
vim.keymap.set("n", "o", "<nop>")
vim.keymap.set("n", "O", "<nop>")
vim.keymap.set("n", "h", "<nop>")

vim.keymap.set("x", "c", '"_c', { desc = "Cut Void" })
vim.keymap.set("x", edit .. "c", '"+c', { desc = "Cut" })
vim.keymap.set("x", "d", '"_d', { desc = "Cut Void" })
vim.keymap.set("x", edit .. "d", '"+d', { desc = "Cut" })

vim.keymap.set("x", "v", "V", { desc = "Visual Line" })
vim.keymap.set({ "n", "x" }, "V", "<c-v>", {
	desc = "Visual Bloc",
})
vim.keymap.set("n", "<c-q>", "<cmd>quitall!<cr>", { desc = "quitall" })
vim.keymap.set({ "n", "x", "o" }, directions.left, "h", { desc = "Left" })
vim.keymap.set({ "n", "x", "o" }, directions.right, "l", { desc = "Right" })
vim.keymap.set({ "n", "x", "o" }, directions.up, "gk", { desc = "Up" })
vim.keymap.set({ "n", "x", "o" }, directions.down, "gj", { desc = "Down" })
vim.keymap.set("n", edit .. reverse("o"), "O", { desc = "Insert Line Above" })
vim.keymap.set("n", edit .. "o", "o", { desc = "Insert Line Below" })
vim.keymap.set("n", edit .. reverse("<tab>"), "<<", { desc = "Indent Decrease" })
vim.keymap.set("n", edit .. "<tab>", ">>", { desc = "Indent Increase" })
vim.keymap.set("n", edit .. reverse("<cr>"), function()
	require("my.blank_line").blank_line(false)
end, { desc = "Blank Line Above" })
vim.keymap.set("n", edit .. "<cr>", function()
	require("my.blank_line").blank_line(true)
end, { desc = "Blank Line Below" })

vim.keymap.set("n", "ow", function()
	local bufnr = vim.api.nvim_get_current_buf()
	dd(require("illuminate.reference").buf_get_references(bufnr))
end, { desc = "Surround" })

vim.keymap.set({ "n", "x" }, edit .. "t", "=", { desc = "Reindent" })
vim.keymap.set("n", edit .. ".", "i.<left>", { desc = "Insert Method" })
vim.keymap.set("n", edit .. ",", "i,<left>", { desc = "Insert Argument" })
vim.keymap.set("n", edit .. " ", "i <left>", { desc = "Insert Word" })

vim.keymap.set("n", move .. move, "``", { desc = "Last Jump" })
vim.keymap.set("n", move .. ";", "g;", { desc = "Last Change" })

vim.keymap.set({ "n", "x", "i" }, "<m-w>", function()
	vim.api.nvim_win_close(0, true)
end, {
	nowait = true,
	desc = "Close Window",
})
vim.keymap.set("n", "<c-j>", function()
	require("my.windows").focus_last_win()
end, { desc = "Window Toggle" })
-- vim.keymap.set("n", "<c-j>", "<c-w><c-p>", { desc = "Window Toggle" })
vim.keymap.set("n", win .. "k", function()
	require("my.windows").close_all_but_current()
end, { desc = "Keep Window (Close Other)" })
vim.keymap.set("n", win .. directions.right, "<cmd>vsplit<cr>", { desc = "Window Split Right" })
vim.keymap.set("n", win .. directions.down, "<cmd>split<cr>", { desc = "Window Split Down" })
vim.keymap.set("n", win .. "g", function()
	require("my.zoom").zoom(0)
end, { desc = "Window Zoom" })

vim.keymap.set("n", "ov", "gv", { desc = "reselect" })

vim.keymap.set("n", web .. "d", function()
	require("my.browser").server()
end, { desc = "Browse Server" })
vim.keymap.set("n", web .. "y", function()
	require("my.browser").search()
end, { desc = "Browse Search" })
vim.keymap.set("n", web .. "u", function()
	require("my.browser").link()
end, { desc = "Browse Link" })
vim.keymap.set("n", web .. "d", function()
	require("my.browser").server()
end, { desc = "Browse Server" })
vim.keymap.set("n", web .. "f", function()
	require("my.browser").file()
end, { desc = "Browse File" })

vim.keymap.set("t", "<s-esc>", "<C-\\><C-n>", { desc = "Term Normal Mode" })
vim.keymap.set("t", "<c-s-v>", '<c-\\><c-n>"+pi', { desc = "Paste" })

-- readline
vim.keymap.set({ "n", "x" }, "<c-b>", "i", { desc = "BOC" })
vim.keymap.set({ "i", "s" }, "<c-b>", function()
	require("my.readline").bwd()
end, { desc = "BOC" })
vim.keymap.set({ "n", "x" }, "<c-f>", "a", { desc = "EOC" })
vim.keymap.set({ "i", "s" }, "<c-f>", function()
	require("my.readline").fwd()
end, { desc = "EOC" })

vim.keymap.set({ "n", "x" }, "<c-a>", "I", { desc = "BOL" })
vim.keymap.set({ "n", "x" }, "<c-e>", "A", { desc = "EOL" })
vim.keymap.set({ "i", "s" }, "<c-e>", function()
	require("my.readline").eol()
end, { desc = "EOL" })

vim.keymap.set("n", domain.appearance .. "n", function()
	vim.wo.number = not vim.wo.number
end, { desc = "Toggle Line Numbers" })

vim.keymap.set("n", domain.appearance .. "g", function()
	vim.o.background = vim.o.background == "light" and "dark" or "light"
end, { desc = "Toggle Light" })

vim.keymap.set("n", domain.appearance .. "l", function()
	vim.o.conceallevel = vim.o.conceallevel == 0 and 2 or 0
end, { desc = "Toggle Conceal Level" })

vim.keymap.set("n", domain.appearance .. "c", function()
	vim.o.concealcursor = vim.o.concealcursor == "n" and "" or "n"
end, { desc = "Toggle Conceal Cursor" })

vim.keymap.set({ "i", "s", "c" }, "<c-v>", "<c-r><c-+>", { desc = "Paste" })

vim.keymap.set("n", domain.move .. "a", function()
	require("my.alternative_file").alternative({
		create = true,
		patterns = {
			{ "(.+)%_spec(%.[%w%d]+)$", "%1%2" },
			{ "(.+)%_test(%.[%w%d]+)$", "%1%2" },
			{ "(.+)%.test(%.[%w%d]+)$", "%1%2" },
			{ "(.+)%.ts", "%1.test.ts" },
			{ "(.+)%.tsx", "%1.test.tsx" },
			{ "(.+)%.lua$", "%1_spec.lua" },
			{ "(.+)%.go$", "%1_test.go" },
			{ "(.+) %- extra%.md$", "%1.md" },
			{ "(.+)%.md$", "%1 - extra.md" },
			{ "(.+)(%.[%w%d]+)$", "%1.test%2" },
			{ "(.+)/__tests__/(.+)", "%1/%2" },
			{ "(.+)/(.+)", "%1/__tests__/%2" },
		},
	})
end, { desc = "Alternative File" })

vim.keymap.set("n", "oml", "<cmd>Lazy<cr>", { desc = "Lazy" })

vim.keymap.set("n", win .. "q", require("my.ui_toggle").toggle, { desc = "Close Widget" })

vim.keymap.set("n", "oq", require("my.lsp").stop_client, { desc = "Stop Lsp Clien" })
