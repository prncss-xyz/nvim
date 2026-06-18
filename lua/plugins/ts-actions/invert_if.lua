local helpers = require("ts-node-action.helpers")
local utils = require("plugins.ts-actions.utils")

local get_node_indent = utils.get_node_indent
local negate_condition = utils.negate_condition
local inner_expr = utils.inner_expr
local ensure_semicolon = utils.ensure_semicolon
local ends_with_return = utils.ends_with_return
local block_body = utils.block_body

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