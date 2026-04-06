local M = {}

local lang_to_key = {
	lua = "lua",
	javascript = "node",
	javascriptreact = "node",
	typescript = "node",
	typescriptreact = "node",
}

function M.from_lang(lang)
	local key = lang_to_key[lang]
	if not key then
		print("unknown lang", vim.inspect(lang))
		return
	end
	return key
end

function M.get_REPL()
	local lang = require("flies.utils.editor").get_lang_at_cursor()
  dd(lang)
	return M.from_lang(lang)
end

return M
