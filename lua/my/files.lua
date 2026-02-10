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

return M
