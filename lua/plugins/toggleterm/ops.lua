local M = {}

M.repl_op = require("flies.operations._with_contents"):new({
	cb = function(lang, contents)
		require("plugins.toggleterm.repl").with(lang, function(key)
			require("plugins.toggleterm.terms").send_lines(key, contents)
		end)
	end,
})

M.agent_op = require("flies.operations._with_contents"):new({
	cb = function(_, contents)
		table.insert(contents, 1, require("plugins.toggleterm.agents").current_position_ref())
		require("plugins.toggleterm.agents").send_lines(contents)
	end,
})

return M
