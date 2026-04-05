local M = {}

M.repl_op = require("flies.operations._with_contents"):new({
	cb = function(lang, contents)
		local term = require("plugins.toggleterm.terms").from_filetype(lang)
		if not term then
			return
		end
		require("plugins.toggleterm.terms").send_lines(term, contents)
	end,
})

M.agent_op = require("flies.operations._with_contents"):new({
	cb = function(_, contents)
		table.insert(contents, 1, require("plugins.toggleterm.agent").current_position_ref())
		require("plugins.toggleterm.terms").send_lines("agent", contents)
	end,
})

return M
