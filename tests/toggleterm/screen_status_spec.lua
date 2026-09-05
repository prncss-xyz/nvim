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

	assert.same("working", child.lua_get("result.status"))
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

	assert.same("blocked", child.lua_get("result.status"))
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

	assert.same("idle", child.lua_get("result.status"))
end

T["screen status"]["supports bottom line regions"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "working", region = "bottom_lines(2)", contains = { "kept blank" } } } },
			"old\nkept blank\n")]])
	assert.same("working", child.lua_get("result.status"))
end

T["screen status"]["supports top non-empty regions"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "working", region = "top_non_empty_lines(1)", contains = { "pinned" }, ["not"] = { { contains = { "later" } } } } } },
			"\npinned chrome\nlater output")]])
	assert.same("working", child.lua_get("result.status"))
end

T["screen status"]["supports after-last-prompt-marker regions"] = function()
	child.lua([=[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ prompt_marker_regex = [[^›]], rules = { { status = "blocked", region = "after_last_prompt_marker", contains = { "confirm" }, ["not"] = { { contains = { "old" } } } } } },
			"old\n› command\nconfirm")]=])
	assert.same("blocked", child.lua_get("result.status"))
end

T["screen status"]["supports before-current-prompt-marker regions"] = function()
	child.lua([=[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ prompt_marker_regex = [[^›]], rules = { { status = "blocked", region = "before_current_prompt_marker", contains = { "question" }, ["not"] = { { contains = { "draft" } } } } } },
			"question\n› draft")]=])
	assert.same("blocked", child.lua_get("result.status"))
end

T["screen status"]["suppresses whole-recent rules at a current prompt marker"] = function()
	child.lua([=[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ default_status = "idle", prompt_marker_regex = [[^›]], rules = { { status = "blocked", region = "whole_recent_without_current_prompt_marker", contains = { "[y/n]" } } } },
			"old [y/n]\n› current prompt")]=])
	assert.same("idle", child.lua_get("result.status"))
end

T["screen status"]["supports current prompt block marker regions"] = function()
	child.lua([=[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ prompt_marker_regex = [[^›]], rules = { { status = "working", region = "current_prompt_block_marker", contains = { "working" } } } },
			"transcript\n• Working (esc to interrupt)\n› draft")]=])
	assert.same("working", child.lua_get("result.status"))
end

T["screen status"]["supports after-current-prompt-block-marker regions"] = function()
	child.lua([=[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ prompt_marker_regex = [[^›]], rules = { { status = "working", region = "after_current_prompt_block_marker", contains = { "details", "draft" }, ["not"] = { { contains = { "old" } } } } } },
			"old\n• details\n› draft")]=])
	assert.same("working", child.lua_get("result.status"))
end

T["screen status"]["supports above-prompt-box regions"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "working", region = "above_prompt_box", contains = { "waiting" }, ["not"] = { { contains = { "draft" } } } } } },
			table.concat({ "waiting", "────────────────", "❯ draft", "────────────────" }, "\n"))]])
	assert.same("working", child.lua_get("result.status"))
end

T["screen status"]["supports last-non-empty-above-prompt-box regions"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "working", region = "last_non_empty_above_prompt_box", contains = { "background agents" }, ["not"] = { { contains = { "older" } } } } } },
			table.concat({ "older", "Waiting for 2 background agents", "", "────────────────", "❯ draft", "────────────────" }, "\n"))]])
	assert.same("working", child.lua_get("result.status"))
end

T["screen status"]["returns skip-state-update metadata"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "unknown", skip_state_update = true, contains = { "overlay" } } } }, "overlay")]])
	assert.same(true, child.lua_get("result.skip_state_update"))
end

T["screen status"]["returns visible-idle metadata"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "idle", visible_idle = true, contains = { "prompt" } } } }, "prompt")]])
	assert.same(true, child.lua_get("result.visible_idle"))
end

T["screen status"]["returns visible-blocker metadata"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "blocked", visible_blocker = true, contains = { "approval" } } } }, "approval")]])
	assert.same(true, child.lua_get("result.visible_blocker"))
end

T["screen status"]["returns visible-working metadata"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "working", visible_working = true, contains = { "running" } } } }, "running")]])
	assert.same(true, child.lua_get("result.visible_working"))
end

T["screen status"]["keeps the earlier rule when priorities tie"] = function()
	child.lua([[local detect = require("plugins.toggleterm.terms.screen_status").detect
		result = detect({ rules = { { status = "working", priority = 10 }, { status = "blocked", priority = 10 } } }, "screen")]])
	assert.same("working", child.lua_get("result.status"))
end

return T
