local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path]])
		end,
		post_once = child.stop,
	},
})

T["screen status"] = MiniTest.new_set()

T["screen status"]["detects pi working output"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({
			rules = {
				{ status = "working", contains = { "Working..." } },
			},
		}, "prompt\nWorking...")]])

	assert.same("working", child.lua_get("result"))
end

T["screen status"]["chooses the highest-priority matching claude rule"] = function()
	child.lua([=[local detect = require("plugins.toggleterm.terms.screen_status").detect
		local manifest = {
			rules = {
				{ status = "idle", priority = 10, region = "prompt_box_body", line_regex = { [[^\s*❯]] } },
				{
					status = "blocked",
					priority = 20,
					region = "after_last_horizontal_rule",
					contains = { "do you want to proceed?" },
					any = {
						{ line_regex = { [[^\s*1\.\s*Yes]] } },
						{ line_regex = { [[^\s*❯?\s*Yes]] } },
					},
				},
			},
		}
		result = detect(manifest, table.concat({
			"────────────────────",
			"❯ run tests",
			"────────────────────",
			"Do you want to proceed?",
			"1. Yes",
			"2. No",
		}, "\n"))]=])

	assert.same("blocked", child.lua_get("result"))
end

T["screen status"]["supports negative gates and bottom non-empty regions"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({
			rules = {
				{
					status = "idle",
					region = "bottom_non_empty_lines(2)",
					contains = { "❯" },
					["not"] = { { contains = { "esc to cancel" } } },
				},
			},
		}, "old output\nesc to cancel\nstatus footer\n❯ \n")]])

	assert.same("idle", child.lua_get("result"))
end

return T
