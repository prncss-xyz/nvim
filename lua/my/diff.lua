local M = {}

function M.cp(filename)
	local op = require("flies.operations._with_contents"):new({
		cb = function(_, contents)
			local txt = table.concat(contents, ", ")
			file = io.open(filename, "w")
			file:write(txt)
			file:close()
		end,
	})
	op:call({})
end

return M
