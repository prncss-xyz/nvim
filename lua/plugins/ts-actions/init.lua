local convert_ternary_to_if = require("plugins.ts-actions.convert_ternary_to_if")
local invert_if = require("plugins.ts-actions.invert_if")
local invert_ternary = require("plugins.ts-actions.invert_ternary")

local ternary_actions = {
	{ convert_ternary_to_if, name = "Convert to if/else" },
	{ invert_ternary, name = "Invert ternary" },
}

return {
	{
		"ckolkey/ts-node-action",
		opts = {
			javascript = {
				["ternary_expression"] = ternary_actions,
				["if_statement"] = invert_if,
			},
			typescript = {
				["ternary_expression"] = ternary_actions,
				["if_statement"] = invert_if,
			},
			javascriptreact = {
				["ternary_expression"] = ternary_actions,
				["if_statement"] = invert_if,
			},
			typescriptreact = {
				["ternary_expression"] = ternary_actions,
				["if_statement"] = invert_if,
			},
		},
		lazy = false,
	},
}