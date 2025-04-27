local reverse = require("my.parameters").reverse
local domain = require("my.parameters").domain
local theme = require("my.parameters").theme
local edit = domain.edit
local move = domain.move
local web = domain.web
local win = domain.win
local directions = require("my.parameters").directions
local recompose = require("flies.actions.move_again").recompose2

vim.keymap.del("n", "gcc")
vim.keymap.set("n", "gra", "<nop>")
vim.keymap.set("x", "gra", "<nop>")
vim.keymap.set("n", "gri", "<nop>")
vim.keymap.set("n", "grn", "<nop>")
vim.keymap.set("n", "grr", "<nop>")
vim.keymap.set("n", "o", "<nop>")
vim.keymap.set("n", "O", "<nop>")
vim.keymap.set("n", "h", "<nop>")

vim.keymap.set("x", "c", '"_c', { desc = "cut void" })
vim.keymap.set("x", edit .. "c", '""c', { desc = "cut" })
vim.keymap.set("x", "d", '"_d', { desc = "cut void" })
vim.keymap.set("x", edit .. "d", '""d', { desc = "cut" })

vim.keymap.set("x", "v", "V", { desc = "visual line" })
vim.keymap.set({ "n", "x" }, "V", "<c-v>", { desc = "visual bloc" })

vim.keymap.set("n", "<c-q>", "<cmd>quitall!<cr>", {
	desc = "quitall",
})
vim.keymap.set("n", "<m-t>", ":b#<cr>", { desc = "toggle last buffer" })
vim.keymap.set({ "n", "x", "o" }, directions.left, "h", { desc = "left" })
vim.keymap.set({ "n", "x", "o" }, directions.right, "l", { desc = "right" })
vim.keymap.set({ "n", "x", "o" }, directions.up, "gk", { desc = "up" })
vim.keymap.set({ "n", "x", "o" }, directions.down, "gj", { desc = "down" })
vim.keymap.set("n", edit .. reverse("o"), "O", { desc = "join" })
vim.keymap.set("n", edit .. "o", "o", { desc = "join" })
vim.keymap.set("n", edit .. reverse("<tab>"), "<<", { desc = "indent decrease" })
vim.keymap.set("n", edit .. "<tab>", ">>", { desc = "indent increase" })
vim.keymap.set("n", edit .. reverse("<cr>"), function()
	require("my.blank_line").blank_line(false)
end, { desc = "blank line above" })
vim.keymap.set("n", edit .. "<cr>", function()
	require("my.blank_line").blank_line(true)
end, { desc = "blank line below" })

vim.keymap.set({ "n", "x" }, edit .. "t", "=", { desc = "reindent" })
vim.keymap.set("n", edit .. ".", "i.<left>", { desc = "insert mehtod" })
vim.keymap.set("n", edit .. ",", "i,<left>", { desc = "insert argument" })
vim.keymap.set("n", edit .. " ", "i <left>", { desc = "insert word" })

vim.keymap.set("n", move .. move, "``", { desc = "last jump" })
vim.keymap.set("n", move .. ";", "g;", { desc = "last change" })

-- TODO: close everything but current window
vim.keymap.set({ "n", "x", "i" }, "<m-w>", function()
	vim.api.nvim_win_close(0, true)
end, {
	nowait = true,
	desc = "Close Window",
})
vim.keymap.set("n", "<c-j>", "<c-w><c-p>", { desc = "Window Toggle" })
vim.keymap.set("n", win .. "k", function()
	require("my.windows").close_all_but_current()
end, { desc = "Keep Window (Close Other)" })
vim.keymap.set("n", win .. directions.right, "<cmd>vsplit<cr>", { desc = "window split right" })
vim.keymap.set("n", win .. directions.down, "<cmd>split<cr>", { desc = "window split down" })

vim.keymap.set("n", web .. "d", function()
	require("my.browser").server()
end, { desc = "browse server" })

vim.keymap.set("n", web .. "y", function()
	require("my.browser").search()
end, { desc = "browse search" })
vim.keymap.set("n", web .. "u", function()
	require("my.browser").link()
end, { desc = "browse link" })
vim.keymap.set("n", web .. "d", function()
	require("my.browser").server()
end, { desc = "browse server" })
vim.keymap.set("n", web .. "f", function()
	require("my.browser").file()
end, { desc = "browse file" })

vim.keymap.set("t", "<s-esc>", "<C-\\><C-n>", { desc = "term normal mode" })
vim.keymap.set("t", "<c-s-v>", '<c-\\><c-n>"+pi', { desc = "paste" })

-- readline
vim.keymap.set({ "n", "x", "i", "s" }, "<c-b>", function()
	require("my.readline").bwd()
end, { desc = "Char Backward" })
vim.keymap.set({ "n", "x", "i", "s" }, "<c-f>", function()
	require("my.readline").fwd()
end, { desc = "Char Forward" })
vim.keymap.set({ "n", "x", "i", "s" }, "<c-e>", function()
	require("my.readline").eol()
end, { desc = "Char Forward" })

vim.keymap.set("n", domain.appearance .. "g", function()
	vim.o.background = vim.o.background == "light" and "dark" or "light"
end, { desc = "Toggle Light" })

vim.keymap.set("n", domain.appearance .. "l", function()
	vim.o.conceallevel = vim.o.conceallevel == 0 and 2 or 0
end, { desc = "toggle conceal level" })

vim.keymap.set("n", domain.appearance .. "c", function()
	vim.o.concealcursor = vim.o.concealcursor == "n" and "" or "n"
end, { desc = "toggle conceal cursor" })

vim.keymap.set("n", move .. reverse("d"), function()
	recompose("<Plug>(unimpaired-directory-previous)", "<Plug>(unimpaired-directory-next)", false)
end, { desc = "previous directory file" })
vim.keymap.set("n", move .. "d", function()
	recompose("<Plug>(unimpaired-directory-previous)", "<Plug>(unimpaired-directory-next)", true)
end, { desc = "previous directory file" })

vim.keymap.set("n", domain.file .. "a", function()
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
