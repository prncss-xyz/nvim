local M = {}

local agents = require("neoterm.terms.middlewares.agents")
local sandbox = require("neoterm.terms.middlewares.sandbox")

---Apply all middlewares to an item and return the transformed item.
---Agents run first (they may set a default sandbox), then sandbox wraps the cmd.
function M.apply_middleware(item)
	if item.agent then
		item = agents.agent(item)
	end
	if item.sandbox then
		item = sandbox.sandbox(item)
	end
	return item
end

return M
