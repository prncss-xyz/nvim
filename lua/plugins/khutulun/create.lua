local M = {}

local function get_snip(target)
	local rel = vim.fn.fnamemodify(target, ":.")
	local snips = require("plugins.khutulun.snips")
	for _, entry in ipairs(snips) do
		if rel:match(entry.pattern) then
			return entry.fn
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
