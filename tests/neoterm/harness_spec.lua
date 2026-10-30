local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. package.path
				root = vim.fn.tempname()
				artifacts = root .. "/artifacts"
				target = artifacts .. "/orphan"
				vim.fn.mkdir(target, "p")
				package.loaded["neoterm.config"] = {
					dirs = { projects = root .. "/projects", artifacts = artifacts },
					default_branches = { "main" },
					llm_query = "name-task",
					tasks = { create_task_name = "{input}" },
				}
				harness = require("neoterm.harness")
			]])
		end,
		post_case = function()
			child.lua([[vim.fn.delete(root, "rf")]])
		end,
		post_once = child.stop,
	},
})

T["picker includes directories without checkouts"] = function()
	child.lua([[
		vim.ui.select = function(items)
			assert(vim.tbl_contains(items, target))
			selected = true
		end
		harness.select_artifact_directory(root .. "/projects/current/main", function() end)
		assert(selected)
	]])
end

T["orphan task naming uses its directory and preserves existing tasks"] = function()
	child.lua([[
		vim.fn.mkdir(target .. "/todo-example", "p")
		vim.fn.writefile({ "original" }, target .. "/todo-example/task.md")
		vim.fn.mkdir(target .. "/todo-example-000", "p")
		vim.system = function(command, opts, callback)
			assert(opts.cwd == target)
			if command[1] == "name-task" then
				callback({ code = 0, stdout = "todo-example", stderr = "" })
			else
				assert(command[1] == "git")
				callback({ code = 128 })
			end
		end
		harness.create_artifact("new task", "task.md", root .. "/projects/unrelated/main", target)
		assert(vim.wait(1000, function()
			return vim.fn.filereadable(target .. "/todo-example-001/task.md") == 1
		end))
		assert(vim.fn.readfile(target .. "/todo-example/task.md")[1] == "original")
		assert(vim.fn.readfile(target .. "/todo-example-001/task.md")[1] == "new task")
	]])
end

return T
