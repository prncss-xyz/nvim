local T = MiniTest.new_set()

T["terminal item formatting"] = MiniTest.new_set()

T["terminal item formatting"]["marks unseen terminals after the identifier"] = function()
	local format_item = require("plugins.toggleterm.terms.format_item").format_item(false)
	local item = {
		key = "agent",
		instance_count = 1,
		status = "working",
		display_name = "agent",
		seen = false,
	}

	assert(format_item(item):find("agent:1*", 1, true))
	item.seen = true
	assert(not format_item(item):find("agent:1*", 1, true))
end

return T
