local M = {}

local master = "/tmp/__master.txt"
local variant = "/tmp/__variant.txt"

function M.cp(filename, after)
	local op = require("flies.operations._with_contents"):new({
		cb = function(_, contents)
			local txt = table.concat(contents, ", ")
			local file = io.open(filename, "w")
			if not file then
				return
			end
			file:write(txt)
			file:close()
			if after then
				after()
			end
		end,
	})
	op:call({})
end

function M.master()
	M.cp(master)
end

function M.variant()
	M.cp(variant, function()
		require("plugins.toggleterm.terms").rerun({ key = "diff" })
	end)
end

function M.get_cmd()
	return string.format("wdiff %q %q|colordiff", master, variant)
end

return M
