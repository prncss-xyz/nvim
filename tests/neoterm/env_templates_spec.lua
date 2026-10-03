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

T["command and env use prompt variables with command cwd"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local cwd = vim.fs.joinpath(root, "projects", "sample", "main")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(vim.fs.joinpath(cwd, ".git"), "p")
		package.loaded["neoterm.config"] = {
			dirs = { projects = vim.fs.joinpath(root, "projects"), artifacts = vim.fs.joinpath(root, "artifacts") },
			default_branches = { "main" },
		}
		local put = require("neoterm.put.init")
		local env = { CONTEXT = "{artifacts}/tasks", LITERAL = "unchanged" }
		local command = { "echo", "{artifacts}/tasks" }
		local ctx = { cwd = cwd, path = vim.fs.joinpath(root, "elsewhere", "file.txt") }
		result = {
			env = put.expand_values(env, ctx),
			string_command = put.expand_values("echo {artifacts}/tasks", ctx),
			list_command = put.expand_values(command, ctx),
			original = env.CONTEXT,
			original_command = command[2],
			prompt = put.template("{artifacts}/tasks")({ path = cwd }),
		}
	]])
	local result = child.lua_get("result")
	assert.same(result.prompt, result.env.CONTEXT)
	assert.same("echo " .. result.prompt, result.string_command)
	assert.same({ "echo", result.prompt }, result.list_command)
	assert.same("unchanged", result.env.LITERAL)
	assert.same("{artifacts}/tasks", result.original)
	assert.same("{artifacts}/tasks", result.original_command)
end

return T
