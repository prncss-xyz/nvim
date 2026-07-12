local M = {}

local function get_snip(target)
	local snips = require("plugins.khutulun.snips")
	for k, v in pairs(snips) do
		if target:match(k) then
			return v
		end
	end
end

function M.create(target)
	local snippet = get_snip(target)
	if not snippet then
		vim.cmd.edit(target)
	else
		vim.cmd.edit(target)
		local luasnip = require("luasnip")
		vim.cmd.startinsert()
		luasnip.snip_expand(luasnip.snippet("", snippet()), {})
	end
end

return M
