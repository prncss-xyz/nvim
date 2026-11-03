local hash = require("neoterm.helpers.hash")

local T = MiniTest.new_set()

T["is a short deterministic base 36 digest"] = function()
	local seen = {}
	for _, input in ipairs({ "", "stores", "neomux/branch-handling", "outer/inner", "misc" }) do
		local value = hash(input)
		assert(value == hash(input))
		assert(value:match("^[0-9a-z]+$"), value)
		assert(#value <= 8, value)
		assert(not seen[value], value)
		seen[value] = true
	end
	assert(hash("neomux/branch-handling") ~= hash("neomux/branch handling"))
end

return T
