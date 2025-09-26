local M = {}

function M.reverse(key)
	return "p" .. key
end

M.ai_insert = {
	accept = "<c-l>",
	clear = "<c-c>",
	next = "<c-9>",
	prev = "<c-0>",
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
