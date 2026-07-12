describe("ts actions", function()
	local original_helpers

	local function node(kind, text, fields, children, opts)
		opts = opts or {}
		return {
			_text = text,
			type = function()
				return kind
			end,
			field = function(_, name)
				return (fields or {})[name] or {}
			end,
			iter_children = function()
				local index = 0
				return function()
					index = index + 1
					return (children or {})[index]
				end
			end,
			named = function()
				return opts.named ~= false
			end,
			start = function()
				return opts.row or 0, 0
			end,
			next_named_sibling = function()
				return opts.next
			end,
		}
	end

	local function binary(left, operator, right)
		local operator_node = node(operator, operator, nil, nil, { named = false })
		return node("binary_expression", left._text .. " " .. operator .. " " .. right._text, {
			left = { left },
			right = { right },
		}, { left, operator_node, right })
	end

	before_each(function()
		original_helpers = package.preload["ts-node-action.helpers"]
		package.loaded["ts-node-action.helpers"] = nil
		package.loaded["plugins.ts-actions.utils"] = nil
		package.loaded["plugins.ts-actions.convert_ternary_to_if"] = nil
		package.loaded["plugins.ts-actions.invert_if"] = nil
		package.loaded["plugins.ts-actions.invert_ternary"] = nil
		package.preload["ts-node-action.helpers"] = function()
			return {
				node_text = function(target)
					return target._text
				end,
			}
		end
		vim.bo.shiftwidth = 2
		vim.bo.expandtab = true
	end)

	after_each(function()
		package.preload["ts-node-action.helpers"] = original_helpers
		package.loaded["ts-node-action.helpers"] = nil
		package.loaded["plugins.ts-actions.utils"] = nil
		package.loaded["plugins.ts-actions.convert_ternary_to_if"] = nil
		package.loaded["plugins.ts-actions.invert_if"] = nil
		package.loaded["plugins.ts-actions.invert_ternary"] = nil
	end)

	it("converts a ternary to an indented if/else IIFE", function()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "  const value = ready ? load() : fallback" })
		local condition = node("identifier", "ready")
		local consequence = node("call_expression", "load()")
		local alternative = node("identifier", "fallback")
		local ternary = node("ternary_expression", "ready ? load() : fallback", {
			condition = { condition },
			consequence = { consequence },
			alternative = { alternative },
		}, nil, { row = 0 })

		local replacement, options = require("plugins.ts-actions.convert_ternary_to_if")(ternary)

		assert.same({
			"(() => {",
			"    if (ready) {",
			"      return load();",
			"    } else {",
			"      return fallback;",
			"    }",
			"  })()",
		}, replacement)
		assert.same({ cursor = {}, format = true }, options)
	end)

	it("inverts a ternary's binary condition and branches", function()
		local left = node("identifier", "a")
		local right = node("identifier", "b")
		local condition = binary(left, ">", right)
		local consequence = node("identifier", "larger")
		local alternative = node("identifier", "smaller")
		local ternary = node("ternary_expression", "a > b ? larger : smaller", {
			condition = { condition },
			consequence = { consequence },
			alternative = { alternative },
		})

		local replacement, options = require("plugins.ts-actions.invert_ternary")(ternary)

		assert.same({ "a <= b ? smaller : larger" }, replacement)
		assert.same({ cursor = {}, format = true }, options)
	end)

	it("inverts braceless if/else branches", function()
		local condition = node("identifier", "ready")
		local consequence = node("expression_statement", "load();")
		local alternative_body = node("expression_statement", "fallback()")
		local else_clause = node("else_clause", "else fallback()", nil, { alternative_body })
		local statement = node("if_statement", "if (ready) load(); else fallback()", {
			condition = { node("parenthesized_expression", "(ready)", nil, { condition }) },
			consequence = { consequence },
			alternative = { else_clause },
		})

		local replacement, options = require("plugins.ts-actions.invert_if")(statement)

		assert.same({ "if (!ready) fallback(); else load();" }, replacement)
		assert.same({ cursor = {}, format = true }, options)
	end)

	it("inverts block if/else branches while preserving indentation", function()
		vim.api.nvim_buf_set_lines(0, 0, -1, false, { "  if (a > b) {" })
		local left = node("identifier", "a")
		local right = node("identifier", "b")
		local condition = binary(left, ">", right)
		local consequence = node("statement_block", "{ return larger; }")
		local alternative_body = node("statement_block", "{ return smaller; }")
		local else_clause = node("else_clause", "else { ... }", nil, { alternative_body })
		local statement = node("if_statement", "if (a > b) { ... }", {
			condition = { node("parenthesized_expression", "(a > b)", nil, { condition }) },
			consequence = { consequence },
			alternative = { else_clause },
		}, nil, { row = 0 })

		local replacement, options = require("plugins.ts-actions.invert_if")(statement)

		assert.same({
			"  if (a <= b) {",
			"    return smaller;",
			"  } else {",
			"    return larger;",
			"  }",
		}, replacement)
		assert.same({ cursor = {}, format = true, target = statement }, options)
	end)

	it("inverts an early-return if by moving its following return into the branch", function()
		local condition = node("identifier", "ready")
		local consequence = node("return_statement", "return loaded;")
		local following_return = node("return_statement", "return fallback;")
		local statement = node("if_statement", "if (ready) return loaded;", {
			condition = { node("parenthesized_expression", "(ready)", nil, { condition }) },
			consequence = { consequence },
		}, nil, { next = following_return })

		local replacement, options = require("plugins.ts-actions.invert_if")(statement)

		assert.same({ "if (!ready) return fallback;", "return loaded;" }, replacement)
		assert.same({ cursor = {}, format = true, target = { statement, following_return } }, options)
	end)

	it("rejects nodes that cannot be transformed", function()
		local identifier = node("identifier", "value")
		local non_returning_if = node("if_statement", "if (ready) load();", {
			condition = { node("parenthesized_expression", "(ready)") },
			consequence = { node("expression_statement", "load();") },
		})

		assert(require("plugins.ts-actions.convert_ternary_to_if")(identifier) == nil)
		assert(require("plugins.ts-actions.invert_ternary")(identifier) == nil)
		assert(require("plugins.ts-actions.invert_if")(non_returning_if) == nil)
	end)
end)
