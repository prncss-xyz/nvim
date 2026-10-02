local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["direct prompts run with input"] = function()
	child.lua([[local scheduled
		local input_callback
		local captured

		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		package.loaded["neoterm.config"] = { prompts = {} }
		vim.schedule = function(callback) scheduled = callback end
		vim.ui.input = function(_, callback) input_callback = callback end

		require("neoterm.prompts").run(function(input, prompt)
			input(prompt, function(contents) captured = { contents, prompt } end)
		end, "task")
		assert(scheduled)
		scheduled()
		assert(input_callback)
		input_callback("new task")
		result = captured
	]])

	assert.same({ "new task", "task" }, child.lua_get("result"))
end

return T
