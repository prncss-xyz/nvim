local M = {}

function M.get_REPL_from_lang(lang)
	local key = require("plugins.toggleterm.config").lang_to_REPL[lang]
	if not key then
		return nil
	end
	return key
end

function M.get_REPL()
	local lang = require("flies.utils.editor").get_lang_at_cursor()
	return M.get_REPL_from_lang(lang)
end

return M
