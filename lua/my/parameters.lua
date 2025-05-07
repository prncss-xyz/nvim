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
	file = "f",
	run = "u",
	comment = "k",
	buffers = "b",
	scratch = "o",
}

M.domain = {
	move = "g",
	edit = "h",
	file = "of",
	win = "r",
	ai = "oa",
	web = "oy",
	snippets = "ob",
	appearance = "og",
	run = "ou",
	pick = "t",
}

M.directions = {
	down = "j",
	up = "k",
	left = "l",
	right = ";",
	search = "é",
	next_search = "<c-j>",
	prev_search = "<c-x>",
}

M.selection_chars = "asdfjkl;ghqweruiopzxcvm,étybn"

return M
