local M = {}

function M.is_file(path)
	local f = io.open(path, "r")
	if f ~= nil then
		io.close(f)
		return true
	else
		return false
	end
end

function M.edit_most_recent_file()
	require("plenary").job
		:new({
			command = "sh",
			args = {
				"-c",
				[[fd . -t f -x stat -f "%m %N" | sort -rn | head -1 | cut -f2- -d" "]],
			},
			on_exit = function(j, _)
				local filename = j:result()[1]
				if filename then
					vim.schedule(function()
						vim.cmd.edit(filename)
					end)
				end
			end,
		})
		:start()
end

function M.edit()
	local name = vim.fn.expand("<cWORD>")
	if name == "" then
		name = vim.fn.expand("<cfile>")
	end
	name = name:gsub("^['\"`({<[]+", "")
	name = name:gsub("['\"`)}>%],.;]+$", "")

	local path, line, col = name:match("^(.+):(%d+):(%d+)$")
	if path then
		vim.cmd.edit(vim.fn.fnameescape(path))
		vim.cmd(line)
		vim.cmd("normal! " .. col .. "|")
		return
	end
	path, line = name:match("^(.+):(%d+)$")
	if path then
		vim.cmd.edit(vim.fn.fnameescape(path))
		vim.cmd(line)
		return
	end
	vim.cmd.edit(vim.fn.fnameescape(name))
end

return M
