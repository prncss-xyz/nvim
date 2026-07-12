local M = {}

M.repl_op = require("flies.operations._with_contents"):new({
	cb = function(lang, contents)
		local key = require("plugins.toggleterm.repl").get_REPL_from_lang(lang)
		require("plugins.toggleterm.terms").send_str({ key = key }, contents)
	end,
})

return M
