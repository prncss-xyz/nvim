local M = {}

function M.reverse(key)
	return "p" .. key
end

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
	move = "g",
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
}

M.directions = {
	down = "j",
	up = "k",
	left = ";",
	right = "l",
	search = "é",
	next_search = "<c-j>",
	prev_search = "<c-x>",
}

M.selection_chars = "asdfjkl;ghqweruiopzxcvm,étybn"

return M
