local helpers = require("ts-node-action.helpers")
local utils = require("plugins.ts-actions.utils")

local get_node_indent = utils.get_node_indent

--- Ensure a statement text ends with a semicolon if needed.
--- Expression nodes (call_expression, identifier, etc.) that become
--- standalone then-clauses need a trailing ';' to form valid JS/TS.
---@param text string
---@return string
local function ensure_semicolon(text)
	if text:sub(-1) ~= ";" and text:sub(-1) ~= "}" then
		return text .. ";"
	end
	return text
end

local flip_ops = {
	["=="] = "!=",
	["!="] = "==",
	["==="] = "!==",
	["!=="] = "===",
	[">"] = "<=",
	["<"] = ">=",
	[">="] = "<",
	["<="] = ">",
	["&&"] = "||",
	["||"] = "&&",
}

--- Negate the condition expression text.
--- - unary `!expr` → `expr`  (strip existing negation)
--- - binary with flip-able operator → flip operator
--- - anything else → `!(expr)`
---@param inner TSNode  the expression inside the parens
---@return string
local function negate_condition(inner)
	if inner:type() == "unary_expression" then
		for child in inner:iter_children() do
			if not child:named() and helpers.node_text(child) == "!" then
				return helpers.node_text(inner:field("argument")[1])
			end
		end
	end

	if inner:type() == "binary_expression" then
		local op_text = ""
		for child in inner:iter_children() do
			if not child:named() then
				local t = helpers.node_text(child)
				if flip_ops[t] then
					op_text = t
					break
				end
			end
		end
		local flipped = flip_ops[op_text]
		if flipped then
			local left = helpers.node_text(inner:field("left")[1])
			local right = helpers.node_text(inner:field("right")[1])
			return left .. " " .. flipped .. " " .. right
		end
	end

	-- only parenthesize when negating logical operators (lower precedence than !)
	local needs_parens = inner:type() == "binary_expression" or inner:type() == "ternary_expression"
	if needs_parens then
		return "!(" .. helpers.node_text(inner) .. ")"
	end
	return "!" .. helpers.node_text(inner)
end

--- Get the inner expression of a parenthesized_expression
---@param paren TSNode
---@return TSNode|nil
local function inner_expr(paren)
	for child in paren:iter_children() do
		if child:named() then
			return child
		end
	end
end

--- Check whether a node ends with a return_statement
---@param node TSNode
---@return boolean
local function ends_with_return(node)
	if node:type() == "return_statement" then
		return true
	end
	if node:type() == "statement_block" then
		local last
		for child in node:iter_children() do
			if child:named() then
				last = child
			end
		end
		return last ~= nil and last:type() == "return_statement"
	end
	return false
end

--- Extract the body text of a statement_block (strips outer braces)
---@param node TSNode
---@return table  lines
local function block_body(node)
	if node:type() ~= "statement_block" then
		-- e.g. a single expression without braces — ensure it forms a valid statement
		return { ensure_semicolon(helpers.node_text(node)) }
	end
	local text = helpers.node_text(node)
	if type(text) == "string" then
		text = { text }
	end
	-- strip opening { and closing }
	local body = {}
	for i, line in ipairs(text) do
		if i == 1 then
			line = line:gsub("^%s*{%s*", "")
		end
		if i == #text then
			line = line:gsub("%s*}%s*$", "")
		end
		if line ~= "" then
			table.insert(body, line)
		end
	end
	return body
end

--- ts-node-action handler: invert if/else branches and negate condition
---@param node TSNode  an if_statement node
---@return table|nil replacement, table|nil opts
return function(node)
	if node:type() ~= "if_statement" then
		return nil
	end

	local condition_paren = node:field("condition")[1]
	local consequence = node:field("consequence")[1]
	local alternative = node:field("alternative")

	local else_body
	local implicit_else = false
	local target = node

	if alternative and #alternative > 0 then
		local else_clause = alternative[1]
		for child in else_clause:iter_children() do
			if child:named() then
				else_body = child
				break
			end
		end
	else
		-- no else: check for implicit else via early-return pattern
		-- if (cond) { return ...; } return ...;
		if not ends_with_return(consequence) then
			return nil
		end
		local next = node:next_named_sibling()
		if not next or not ends_with_return(next) then
			return nil
		end
		else_body = next
		implicit_else = true
		target = { node, next }
	end

	local new_condition = negate_condition(inner_expr(condition_paren))

	-- braceless: both branches are simple statements (not statement_blocks)
	local braceless = consequence:type() ~= "statement_block" and else_body:type() ~= "statement_block"

	if braceless then
		local if_text = helpers.node_text(consequence)
		local else_text = ensure_semicolon(helpers.node_text(else_body))
		if implicit_else then
			-- if (!x) return b; return a;
			return { "if (" .. new_condition .. ") " .. else_text, if_text }, {
				cursor = {},
				format = true,
				target = target,
			}
		end
		return { "if (" .. new_condition .. ") " .. else_text .. " else " .. if_text }, { cursor = {}, format = true }
	end

	local indent = get_node_indent(node)
	local unit = utils.get_indent_unit()
	local inner = indent .. unit

	-- build lines
	local lines = {}
	vim.list_extend(lines, { indent .. "if (" .. new_condition .. ") {" })

	local else_lines = block_body(else_body)
	for _, line in ipairs(else_lines) do
		table.insert(lines, inner .. line)
	end

	if implicit_else then
		-- no else block needed: if body ends with return, so rest falls through
		vim.list_extend(lines, { indent .. "}" })
		local if_lines = block_body(consequence)
		for _, line in ipairs(if_lines) do
			table.insert(lines, indent .. line)
		end
	else
		vim.list_extend(lines, { indent .. "} else {" })
		local if_lines = block_body(consequence)
		for _, line in ipairs(if_lines) do
			table.insert(lines, inner .. line)
		end
		vim.list_extend(lines, { indent .. "}" })
	end

	return lines, { cursor = {}, format = true, target = target }
end
