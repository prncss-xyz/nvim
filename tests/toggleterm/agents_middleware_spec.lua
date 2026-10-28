local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua(
				[[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path]]
			)
		end,
		post_once = child.stop,
	},
})

T["agent command and alias settings resolve with caller overrides"] = function()
	child.lua([[
		package.loaded["neoterm.config"] = {
			agents = {
				{ name = "pi", command = { sandbox = "bwrap", varlock = "schema" }, alias = { deep = { model = "deep-model" } } },
			},
		}
		local middleware = require("neoterm.middlewares.agents")
		local default = middleware({ tag = "agent", alias = "deep" })
		local override = middleware({ tag = "agent", alias = "deep", model = "custom", sandbox = false })
		result = {
			{ agent = default.agent, model = default.model, sandbox = default.sandbox, varlock = default.varlock },
			{ agent = override.agent, model = override.model, sandbox = override.sandbox, varlock = override.varlock },
		}
	]])
	assert.same({
		{ agent = "pi", model = "deep-model", sandbox = "bwrap", varlock = "schema" },
		{ agent = "pi", model = "custom", sandbox = false, varlock = "schema" },
	}, child.lua_get("result"))
end

T["skill prefixes the prompt using the harness skill format"] = function()
	child.lua([[
		package.loaded["neoterm.config"] = {
			agents = { { name = "codex" }, { name = "pi" }, { name = "claude" } },
		}
		local middleware = require("neoterm.middlewares.agents")
		result = {
			middleware({ tag = "agent", agent = "codex", skill = "deploy" }).cmd,
			middleware({ tag = "agent", agent = "codex", skill = "deploy", prompt = "now" }).cmd,
			middleware({ tag = "agent", agent = "pi", skill = "deploy", prompt = "now" }).cmd,
			middleware({ tag = "agent", agent = "claude", skill = "deploy", prompt = "now" }).cmd,
		}
	]])
	assert.same({
		{ "codex", "$deploy" },
		{ "codex", "$deploy now" },
		{ "pi", "/skill:deploy now" },
		{ "claude", "use the skill deploy now" },
	}, child.lua_get("result"))
end

T["claude enables OSC status without screen heuristics"] = function()
	child.lua([[
		package.loaded["neoterm.config"] = { agents = { { name = "claude" } } }
		local opts = require("neoterm.middlewares.agents")({ tag = "agent" })
		result = { opts.osc_status, opts.screen_manifest == nil, opts.cmd }
	]])
	assert.same({ true, true, { "claude" } }, child.lua_get("result"))
end

return T
