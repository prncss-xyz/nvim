local helpers = require("ts-node-action.helpers")
local utils = require("plugins.ts-actions.utils")

local get_indent_unit = utils.get_indent_unit
local get_node_indent = utils.get_node_indent

local function construct_if_else_statement(ternary_expression)
	local unit = get_indent_unit()

	local condition = ternary_expression:field("condition")[1]
	local consequence = ternary_expression:field("consequence")[1]
	local alternative = ternary_expression:field("alternative")[1]

	local function make_expression_statement(node)
		if node:type() == "ternary_expression" then
			return construct_if_else_statement(node)
		end

		local text = helpers.node_text(node)
		if type(text) == "table" then
			text = table.concat(text, "\n")
		end

		local lines = vim.split(text, "\n")
		if #lines == 1 then
			return { "return " .. lines[1] .. ";" }
		else
			lines[1] = "return " .. lines[1]
			lines[#lines] = lines[#lines] .. ";"
			return lines
		end
	end

	local lines = {}

	local cond_text = helpers.node_text(condition)
	if type(cond_text) == "table" then
		cond_text = table.concat(cond_text, " ")
	end

	table.insert(lines, "if (" .. cond_text .. ") {")

	local cons_lines = make_expression_statement(consequence)
	for _, l in ipairs(cons_lines) do
		table.insert(lines, unit .. l)
	end

	table.insert(lines, "} else {")

	local alt_lines = make_expression_statement(alternative)
	for _, l in ipairs(alt_lines) do
		table.insert(lines, unit .. l)
	end

	table.insert(lines, "}")
	return lines
end

--- ts-node-action handler: convert ternary_expression -> if/else IIFE
---@param node TSNode
---@return table|nil replacement, table|nil opts
return function(node)
	if node:type() ~= "ternary_expression" then
		return nil
	end

	local indent = get_node_indent(node)
	local unit = get_indent_unit()

	local if_else_lines = construct_if_else_statement(node)

	local lines = {
		"(() => {",
	}
	for _, l in ipairs(if_else_lines) do
		table.insert(lines, indent .. unit .. l)
	end
	table.insert(lines, indent .. "})()")

	return lines, { cursor = {}, format = true }
end
