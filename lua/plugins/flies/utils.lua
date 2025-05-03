local M = {}

function M.add_snips(tbl, lang)
	if true then
		return
	end
	local s = require("luasnip").snippet
	for k, v in pairs(require("plugins.flies.chars")) do
		local snippet = v.snip and v.snip[lang]
		if snippet then
			table.insert(tbl, s(k, snippet))
		end
	end
end

return M
