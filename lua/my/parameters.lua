local M = {}

function M.reverse(key)
	return "p" .. key
end

M.ai_insert = {
  toggle = "<c-.>",
	accept = "<c-k>",
	clear = "<c-c>",
	next = "<c-l>",
	prev = "<c-;>",
  nes = "<c-,>"
}

M.theme = {
	win = "w",
	work = "w",
	find = "é",
	diagnostic = "z",
	symbol = "s",
	reference = "r",
	definition = "d",
	hunk = "h",
	directory = "f",
	run = "u",
	comment = "k",
	buffers = "b",
	scratch = "o",
	project = "c",
}

M.domain = {
  conflict = "oj",
	move = "b",
	edit = "h",
	file = "of",
	git = "oh",
	win = "r",
	ai = "oa",
	web = "oy",
	snippets = "ob",
	appearance = "og",
	run = "ou",
	pick = "t",
	dap = "od",
	language = "ol",
	tests = "ot",
	tabs = "x",
}

M.directions = {
	down = "j",
	up = "k",
	left = ";",
	right = "l",
	search = "é",
}

M.selection_chars = "asdfjkl;ghqweruiopzxcvm,étybn"

return M
