local slug = require("neoterm.helpers.slug")

local T = MiniTest.new_set()

T["replaces spaces and punctuation with single dashes"] = function()
	assert.same("Fix-the-thing", slug("Fix  the thing!"))
	assert.same("a-b-c", slug(" a..b -- c "))
	assert.same("feat-improve-merge-handling", slug("feat-improve-merge-handling"))
	assert.same("flies-nvim", slug("flies.nvim"))
end

return T
