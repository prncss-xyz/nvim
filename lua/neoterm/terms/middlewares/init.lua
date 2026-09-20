local M = {}

local agents = require("neoterm.terms.middlewares.agents")
local sandbox = require("neoterm.terms.middlewares.sandbox")

---Apply all middlewares to an item and return the transformed item.
---Agents run first (they may set a default sandbox), then sandbox wraps the cmd.
---Each middleware checks its own condition and returns the item unchanged when
---it does not apply.
function M.apply_middleware(item)
	item = agents.agent(item)
	item = sandbox.sandbox(item)
	return item
end

return M
