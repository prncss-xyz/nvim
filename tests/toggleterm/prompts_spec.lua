local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["selected prompts run outside the selector callback"] = function()
	child.lua([[local scheduled = {}
		local selector_callback
		local input_callback
		local captured

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["plugins.toggleterm.config"] = {
			prompts = {
				idea = require("plugins.toggleterm.prompt_utils").with_prompt(function(contents, prompt)
					captured = { contents, prompt }
				end),
			},
		}
		vim.ui.select = function(_, _, callback)
			selector_callback = callback
		end
		vim.ui.input = function(opts, callback)
			assert(type(opts.prompt) == "string", "input prompt must be a string")
			input_callback = callback
		end
		vim.schedule = function(callback)
			table.insert(scheduled, callback)
		end

		require("plugins.toggleterm.prompts").prompt()
		selector_callback("idea")
		assert(not input_callback, "prompt ran directly in the selector callback")
		assert(#scheduled == 1, "prompt was not scheduled")
		scheduled[1]()
		assert(input_callback, "scheduled prompt did not run")
		input_callback("captured idea")
		assert(vim.deep_equal(captured, { "captured idea", "idea" }), "prompt context was not used")
	]])
end

T["task prompts create a task inside the current artifact"] = function()
	child.lua([[local created

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["plugins.toggleterm.terms.artifact_cwd"] = {
			contains = function(path) return path == "/artifacts/neomux/topic/index.md" end,
			resolve = function() return "/projects/neomux/main" end,
		}
		package.loaded["plugins.toggleterm.harness"] = {
			create_task = function(input, artifact)
				created = { input, artifact }
			end,
		}
		vim.api.nvim_buf_set_name(0, "/artifacts/neomux/topic/index.md")

		local prompt = require("plugins.toggleterm.prompt_utils").create_task()
		prompt(function(_, callback) callback("new task") end, "task")
		result = created
	]])

	assert.same({ "new task", "/artifacts/neomux/topic/index.md" }, child.lua_get("result"))
end

T["task prompts create a new artifact outside artifacts"] = function()
	child.lua([[local created

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["plugins.toggleterm.terms.artifact_cwd"] = {
			contains = function() return false end,
			resolve = function() return nil end,
		}
		package.loaded["plugins.toggleterm.harness"] = {
			create_artifact = function(input, filename, root)
				created = { input, filename, root }
			end,
		}

		local prompt = require("plugins.toggleterm.prompt_utils").create_task()
		prompt(function(_, callback) callback("new artifact") end, "task")
		result = created
	]])

	local result = child.lua_get("result")
	assert.same("new artifact", result[1])
	assert.same("index.md", result[2])
end

return T
