local M = {}

local function get_snip(target)
	local rel = vim.fn.fnamemodify(target, ":.")
	local snips = require("my.create.snips")
	for _, entry in ipairs(snips) do
		if rel:match(entry.pattern) then
			return entry.fn
		end
	end
end

---Edit `target`, expanding the matching snippet when the file does not exist yet.
---@param target string unescaped path
function M.create(target)
	local snippet = get_snip(target)
	local exists = vim.uv.fs_stat(target) ~= nil
	vim.cmd.edit({ target, magic = { file = false } })
	if not exists and snippet then
		local luasnip = require("luasnip")
		vim.cmd.startinsert()
		luasnip.snip_expand(luasnip.snippet("", snippet()), {})
	end
end

return M
