local open = require("neoterm.helpers.file_windows").open

local function edit_file_under_cursor()
	local name = vim.fn.expand("<cWORD>")
	if name == "" then
		name = vim.fn.expand("<cfile>")
	end
	name = name:gsub("^['\"`({<[]+", "")
	name = name:gsub("['\"`)}>%],.;]+$", "")

	local path, line, col = name:match("^(.+):(%d+):(%d+)$")
	if path then
		if open(path) then
			vim.cmd(line)
			vim.cmd("normal! " .. col .. "|")
		end
		return
	end
	path, line = name:match("^(.+):(%d+)$")
	if path then
		if open(path) then
			vim.cmd(line)
		end
		return
	end
	open(name)
end

return edit_file_under_cursor
