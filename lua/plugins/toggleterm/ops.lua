local M = {}

M.repl_op = require("flies.operations._with_contents"):new({
	cb = function(lang, contents)
		local key = require("plugins.toggleterm.repl").get_REPL_from_lang(lang)
		require("plugins.toggleterm.terms").send_lines(key, contents)
	end,
})

M.agent_op = require("flies.operations._with_contents"):new({
	cb = function(_, contents)
		local key = require("plugins.toggleterm.terms").get_last("agent")
		if not key then
			return
		end
		table.insert(contents, 1, require("plugins.toggleterm.agents").current_position())
		require("plugins.toggleterm.terms").send_lines(key, contents)
	end,
})

return M
