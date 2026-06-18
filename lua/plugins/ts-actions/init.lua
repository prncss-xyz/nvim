local convert_ternary_to_if = require("plugins.ts-actions.convert_ternary_to_if")
local invert_if = require("plugins.ts-actions.invert_if")

return {
	{
		"ckolkey/ts-node-action",
		opts = {
			javascript = {
				["ternary_expression"] = convert_ternary_to_if,
				["if_statement"] = invert_if,
			},
			typescript = {
				["ternary_expression"] = convert_ternary_to_if,
				["if_statement"] = invert_if,
			},
			javascriptreact = {
				["ternary_expression"] = convert_ternary_to_if,
				["if_statement"] = invert_if,
			},
			typescriptreact = {
				["ternary_expression"] = convert_ternary_to_if,
				["if_statement"] = invert_if,
			},
		},
		lazy = false,
	},
}
