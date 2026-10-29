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

T["expands variants in string and function templates"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local cwd = vim.fs.joinpath(projects, "sample", "main")
		local source = vim.fs.joinpath(artifacts, "sample", "feature", "task.md")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(vim.fs.dirname(source), "p")
		vim.fn.writefile({ "task" }, source)
		package.loaded["neoterm.config"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main" },
		}
		package.loaded["neoterm.terms.artifacts.tasks"] = { executables = function() return {} end }
		local commands = require("neoterm.terms.artifacts.commands")
		for _, command in ipairs({
			{ open = true },
			{ tag = "unknown" },
			{ tag = "open", cmd = "echo invalid" },
			{ tag = "agent", cmd = "echo invalid" },
			{ tag = "open", prompt = "invalid" },
		}) do
			local ok = pcall(commands.for_file, {
				cwd = cwd,
				file = source,
				steps = { { name = "invalid", source = "task.md", command = command } },
			})
			assert(not ok, "Invalid command should fail validation")
		end
		local callback_vars, template_vars
		local definitions = commands.for_file({
			cwd = cwd,
			file = source,
			steps = {
				{ name = "var", source = "task.md", variants = { "a", "b" }, command = { cmd = "echo {variant}", title = "{step}" } },
				{ name = "fn", source = "task.md", variants = { "a", "b" }, command = function(vars)
					template_vars = vars
					return { cmd = vars.variant .. " " .. vars.step }
				end, on_success = function(vars) callback_vars = vars end },
			},
		})
		assert(callback_vars == nil)
		definitions[#definitions].on_success()
		assert(callback_vars == template_vars)
		assert(callback_vars.source == '"' .. source .. '"')
		result = vim.tbl_map(function(item)
			return { name = item.name, cmd = item.cmd, title = item.title }
		end, definitions)
	]])
	assert.same({
		{ name = "var:a:feature:feature", cmd = "echo a", title = "var:a:feature:feature" },
		{ name = "var:b:feature:feature", cmd = "echo b", title = "var:b:feature:feature" },
		{ name = "fn:a:feature:feature", cmd = "a fn:a:feature:feature" },
		{ name = "fn:b:feature:feature", cmd = "b fn:b:feature:feature" },
	}, child.lua_get("result"))
end

T["fork strings append literal and expanded suffixes to the artifact branch"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local cwd = vim.fs.joinpath(projects, "sample", "main")
		local source = vim.fs.joinpath(artifacts, "sample", "feature", "task.md")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(vim.fs.dirname(source), "p")
		vim.fn.writefile({ "task" }, source)
		package.loaded["neoterm.config"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main" },
		}
		package.loaded["neoterm.terms.artifacts.tasks"] = { executables = function() return {} end }
		local definitions = require("neoterm.terms.artifacts.commands").for_file({
			cwd = cwd,
			file = source,
			steps = {
				{ name = "literal", source = "task.md", fork = "review", command = { tag = "open" } },
				{ name = "variant", source = "task.md", fork = "{variant}", variants = { "a", "b" }, command = "echo {variant}" },
				{ name = "plain", source = "task.md", fork = true, command = "echo plain" },
				{ name = "current", source = "task.md", fork = false, command = "echo current" },
			},
		})
		result = vim.tbl_map(function(item)
			return vim.fs.relpath(projects, item.cwd)
		end, definitions)
	]])
	assert.same(
		{ "sample/feature-review", "sample/feature-a", "sample/feature-b", "sample/feature", "sample/main" },
		child.lua_get("result")
	)
end

T["nested artifact directories form the branch name"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local cwd = vim.fs.joinpath(projects, "utils-mono", "main")
		local source = vim.fs.joinpath(artifacts, "utils-mono", "stores", "fix-provider-store", "task.md")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(vim.fs.dirname(source), "p")
		vim.fn.writefile({ "task" }, source)
		package.loaded["neoterm.config"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main" },
		}
		package.loaded["neoterm.terms.artifacts.tasks"] = { executables = function() return {} end }
		local definitions = require("neoterm.terms.artifacts.commands").for_file({
			cwd = cwd,
			file = source,
			steps = {
				{ name = "fork", source = "task.md", fork = true, command = { tag = "open" } },
				{ name = "variant", source = "task.md", fork = "{variant}", variants = { "a" }, command = "echo {variant}" },
			},
		})
		result = vim.tbl_map(function(item) return vim.fs.relpath(projects, item.cwd) end, definitions)
	]])
	assert.same({
		"utils-mono/stores-fix-provider-store",
		"utils-mono/stores-fix-provider-store-a",
	}, child.lua_get("result"))
end

T["fork opens a project file only after the worktree is ready"] = function()
	child.lua([[
		local cwd = "/projects/sample/feature"
		local events = {}
		local ready
		package.loaded["neoterm.config"] = {
			dirs = {},
			steps = {},
			create = function(path) table.insert(events, { "open", path }) end,
		}
		package.loaded["neoterm.terms.artifacts.cwd"] = {
			context_dir = function() return cwd end,
			link = function(path, artifacts) table.insert(events, { "link", path, artifacts }) end,
		}
		package.loaded["neoterm.git"] = { ensure_worktree = function(path, callback)
			table.insert(events, { "ensure", path })
			ready = callback
		end }
		package.loaded["neoterm.helpers.project_file"] = { get_project_file = function(path)
			assert(path == cwd)
			return path .. "/src/main.lua"
		end }
		local commands = require("neoterm.terms.artifacts.commands")
		commands.for_file = function()
			return { { name = "fork:feature", cwd = cwd, tag = "open", artifact_dir = "/artifacts/sample/feature" } }
		end
		vim.ui.select = function(items, _, callback) callback(items[1]) end
		commands.select_for_current_file()
		assert(#events == 1)
		ready(false)
		assert(#events == 1)
		ready(true)
		result = events
	]])
	assert.same({
		{ "ensure", "/projects/sample/feature" },
		{ "link", "/projects/sample/feature", "/artifacts/sample/feature" },
		{ "open", "/projects/sample/feature/src/main.lua" },
	}, child.lua_get("result"))
end

T["source arrays prefer the last existing file and target arrays block on any file"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local cwd = vim.fs.joinpath(root, "projects", "sample", "main")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local folder = vim.fs.joinpath(artifacts, "sample", "feature")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(folder, "p")
		local task = vim.fs.joinpath(folder, "task.md")
		local plan = vim.fs.joinpath(folder, "plan.md")
		vim.fn.writefile({ "task" }, task)
		package.loaded["neoterm.config"] = {
			dirs = { projects = vim.fs.joinpath(root, "projects"), artifacts = artifacts },
			default_branches = { "main" },
		}
		package.loaded["neoterm.terms.artifacts.tasks"] = { executables = function() return {} end }
		local commands = require("neoterm.terms.artifacts.commands")
		local step = {
			name = "implement",
			source = { "task.md", "plan.md" },
			target = { "walkthrough.md", "done.md" },
			fork = true,
			command = { cmd = "{source} {target}" },
		}
		local function definitions(file)
			return commands.for_file({ cwd = cwd, file = file, steps = { step } })
		end
		local function check(file, expected)
			local items = definitions(file)
			assert(#items == 1)
			assert(items[1].artifact_source == expected)
			assert(items[1].cmd == '"' .. expected .. '" "' .. folder .. '/walkthrough.md"')
			assert(items[1].cwd == vim.fs.joinpath(root, "projects", "sample", "feature"))
		end
		check(task, task)
		vim.fn.writefile({ "plan" }, plan)
		check(task, plan)
		check(plan, plan)
		local paths = require("neoterm.terms.artifacts.paths")
		assert(#paths.branches(paths.source(plan), { step }) == 1)
		for _, target in ipairs(step.target) do
			local path = vim.fs.joinpath(folder, target)
			vim.fn.writefile({ "done" }, path)
			assert(#definitions(task) == 0)
			vim.fn.delete(path)
		end
		vim.fn.delete(plan)
		check(task, task)
		assert(type(step.source) == "table" and type(step.target) == "table")
	]])
end

return T
