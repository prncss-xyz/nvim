local helpers = require("ts-node-action.helpers")

local M = {}

--- Get the indentation unit (tab or spaces based on buffer settings)
---@return string
function M.get_indent_unit()
	local shiftwidth = vim.api.nvim_get_option_value("shiftwidth", {})
	if shiftwidth == 0 then
		shiftwidth = vim.api.nvim_get_option_value("tabstop", {})
	end
	local expandtab = vim.api.nvim_get_option_value("expandtab", {})
	return expandtab and string.rep(" ", shiftwidth) or "\t"
end

--- Get the leading whitespace of the line containing the node's start row
---@param node TSNode
---@return string
function M.get_node_indent(node)
	local start_row = node:start()
	local line = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]
	if not line then
		return ""
	end
	return line:match("^(%s*)") or ""
end

--- Operator pairs for negation-by-flip
M.flip_ops = {
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
---@param inner TSNode  the expression to negate
---@return string
function M.negate_condition(inner)
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
				if M.flip_ops[t] then
					op_text = t
					break
				end
			end
		end
		local flipped = M.flip_ops[op_text]
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
function M.inner_expr(paren)
	for child in paren:iter_children() do
		if child:named() then
			return child
		end
	end
end

--- Ensure a statement text ends with a semicolon if needed.
--- Expression nodes that become standalone then-clauses need
--- a trailing ';' to form valid JS/TS.
---@param text string
---@return string
function M.ensure_semicolon(text)
	if text:sub(-1) ~= ";" and text:sub(-1) ~= "}" then
		return text .. ";"
	end
	return text
end

--- Check whether a node ends with a return_statement
---@param node TSNode
---@return boolean
function M.ends_with_return(node)
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
function M.block_body(node)
	if node:type() ~= "statement_block" then
		return { M.ensure_semicolon(helpers.node_text(node)) }
	end
	local text = helpers.node_text(node)
	if type(text) == "string" then
		text = { text }
	end
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

--- Flatten node text (table of lines → single string joined by space)
---@param node TSNode
---@return string
function M.flat_text(node)
	local text = helpers.node_text(node)
	if type(text) == "table" then
		return table.concat(text, " ")
	end
	return text
end

return M
