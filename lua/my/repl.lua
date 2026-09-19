local M = {}

local lang_to_REPL = {
	lua = "lua",
	javascript = "node",
	javascriptreact = "node",
	typescript = "node",
	typescriptreact = "node",
}

local function get_REPL_from_lang(lang)
	local key = lang_to_REPL[lang]
	if not key then
		return nil
	end
	return key
end

M.op = require("flies.operations._with_contents"):new({
	cb = function(lang, contents)
		local key = get_REPL_from_lang(lang)
		require("neoterm.terms").put({ key = key }, contents)
	end,
})

function M.get_REPL()
	local lang = require("flies.utils.editor").get_lang_at_cursor()
return get_REPL_from_lang(lang)
end

return M
