local helpers = require("ts-node-action.helpers")
local utils = require("plugins.ts-actions.utils")

local negate_condition = utils.negate_condition

--- ts-node-action handler: invert ternary expression branches and negate condition
--- `a > b ? x : y` → `a <= b ? y : x`
--- `!a ? x : y` → `a ? y : x`
--- `a && b ? x : y` → `a || b ? y : x`
---@param node TSNode  a ternary_expression node
---@return table|nil replacement, table|nil opts
return function(node)
	if node:type() ~= "ternary_expression" then
		return nil
	end

	local condition = node:field("condition")[1]
	local consequence = node:field("consequence")[1]
	local alternative = node:field("alternative")[1]

	local new_condition = negate_condition(condition)
	local cons_text = helpers.node_text(consequence)
	local alt_text = helpers.node_text(alternative)

	if type(cons_text) == "table" then
		cons_text = table.concat(cons_text, "\n")
	end
	if type(alt_text) == "table" then
		alt_text = table.concat(alt_text, "\n")
	end

	local result = new_condition .. " ? " .. alt_text .. " : " .. cons_text

	return { result }, { cursor = {}, format = true }
end