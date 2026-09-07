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
		local artifact

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["plugins.toggleterm.harness"] = {
			create_artifact = function(input, filename)
				artifact = { input, filename }
			end,
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
		selector_callback("Idea: ")
		assert(not input_callback, "prompt ran directly in the selector callback")
		assert(#scheduled == 1, "prompt was not scheduled")
		scheduled[1]()
		assert(input_callback, "scheduled prompt did not run")
		input_callback("captured idea")
		assert(vim.deep_equal(artifact, { "captured idea", "idea.md" }), "prompt input was not used")
	]])
end

return T
