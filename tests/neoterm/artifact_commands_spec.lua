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
		local source = vim.fs.joinpath(artifacts, "sample", "scope", "feature", "task.md")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(vim.fs.dirname(source), "p")
		vim.fn.writefile({ "task" }, source)
		package.loaded["neoterm.config"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main" },
		}
		require("neoterm.terms.artifacts.tasks").executables = function() return {} end
		local commands = require("neoterm.terms.artifacts.commands")
		local fork = vim.fs.joinpath(projects, "sample", require("neoterm.terms.artifacts.paths").source(source).branch)
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
		local callback_vars, callback_output, template_vars
		local definitions = commands.for_file({
			cwd = cwd,
			file = source,
			steps = {
				{ name = "var", source = "task.md", variants = { "a", "b" }, command = { cmd = "echo {variant}", title = "{step}", skill = "{name}" } },
				{ name = "fn", source = "task.md", variants = { "a", "b" }, command = function(vars)
					template_vars = vars
					return { cmd = vars.variant .. " " .. vars.step }
				end, on_success = function(vars, output) callback_vars, callback_output = vars, output end },
			},
		})
		assert(callback_vars == nil)
		local output = {}
		definitions[#definitions].on_success(output)
		assert(callback_output == output)
		assert(callback_vars == template_vars)
		assert(definitions[1].skill == "var")
		assert(definitions[2].skill == "var")
		assert(template_vars.name == "fn")
		assert(callback_vars.source == '"' .. source .. '"')
		assert(template_vars.message == "feat(scope): feature")
		assert(callback_vars.message == "feat(scope): feature")
		assert(callback_vars.cwd == fork)
		local walkthrough = vim.fs.joinpath(vim.fs.dirname(source), "walkthrough.md")
		vim.fn.writefile({ "walkthrough" }, walkthrough)
		local merge = commands.for_file({
			cwd = cwd,
			file = walkthrough,
			steps = { { name = "merge", source = "walkthrough.md", command = { cmd = { "merge-from-current", "{message}" } } } },
		})
		assert(vim.deep_equal(merge[1].cmd, { "merge-from-current", "feat(scope): feature" }))
		vim.fn.writefile({ "Did it." }, vim.fs.joinpath(vim.fs.dirname(source), "implementation.md"))
		merge = commands.for_file({
			cwd = cwd,
			file = walkthrough,
			steps = { { name = "merge", source = "walkthrough.md", command = { cmd = { "merge-from-current", "{message}" } } } },
		})
		assert(vim.deep_equal(merge[1].cmd, { "merge-from-current", "feat(scope): feature\n\nDid it." }))
		result = vim.tbl_map(function(item)
			local name = item.name:gsub(vim.pesc(vim.fs.basename(fork)), "<branch>")
			local title = item.title and item.title:gsub(vim.pesc(vim.fs.basename(fork)), "<branch>")
			local cmd = item.cmd:gsub(vim.pesc(vim.fs.basename(fork)), "<branch>")
			return { name = name, cmd = cmd, title = title }
		end, definitions)
		local calls = 0
		package.loaded["neoterm.config"].steps = {
			{ name = "callback", source = "task.md", on_success = function(vars)
				calls = calls + 1
				assert(vars.source == '"' .. source .. '"')
			end },
			{ name = "noop", source = "task.md" },
		}
		vim.api.nvim_buf_set_name(0, source)
		local ensured, linked = {}, {}
		package.loaded["neoterm.terms.artifacts.cwd"] = {
			context_dir = function() return cwd end,
			link = function(path, folder) table.insert(linked, { path, folder }) end,
		}
		package.loaded["neoterm.git"] = { ensure_worktree = function(path, callback)
			table.insert(ensured, path)
			callback(true)
		end }
		package.loaded["neoterm.terms"] = { start = function() error("Unexpected terminal") end }
		for index = 1, 2 do
			vim.ui.select = function(items, _, callback)
				assert(calls == index - 1)
				callback(items[index])
			end
			commands.select_for_current_file()
		end
		assert(calls == 1)
		assert(vim.deep_equal(ensured, { fork }))
		assert(vim.deep_equal(linked, { { fork, vim.fs.dirname(source) } }))
	]])
	assert.same({
		{ name = "var:a:<branch>:feature", cmd = "echo a", title = "var:a:<branch>:feature" },
		{ name = "var:b:<branch>:feature", cmd = "echo b", title = "var:b:<branch>:feature" },
		{ name = "fn:a:<branch>:feature", cmd = "a fn:a:<branch>:feature" },
		{ name = "fn:b:<branch>:feature", cmd = "b fn:b:<branch>:feature" },
	}, child.lua_get("result"))
end

T["steps fork by default and fork: false in task.md keeps the current cwd"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local cwd = vim.fs.joinpath(projects, "sample", "main")
		local source = vim.fs.joinpath(artifacts, "sample", "scope", "feature", "task.md")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(vim.fs.dirname(source), "p")
		vim.fn.writefile({ "task" }, source)
		package.loaded["neoterm.config"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main" },
		}
		require("neoterm.terms.artifacts.tasks").executables = function() return {} end
		local commands = require("neoterm.terms.artifacts.commands")
		local branch = require("neoterm.terms.artifacts.paths").source(source).branch
		local steps = {
			{ name = "open", source = "task.md", command = { tag = "open" } },
			{ name = "plain", source = "task.md", command = "echo plain" },
			{ name = "merge", source = "task.md", requires_fork = true, command = "echo merge" },
		}
		local function definitions()
			return commands.for_file({ cwd = cwd, file = source, steps = steps })
		end
		for _, item in ipairs(definitions()) do
			assert(item.cwd == vim.fs.joinpath(projects, "sample", branch), item.cwd)
			assert(item.artifact_dir == vim.fs.dirname(source))
			assert(item.refusal == nil)
		end
		vim.fn.writefile({ "---", "fork: false", "---", "task" }, source)
		local items = definitions()
		assert(#items == 3)
		for _, item in ipairs(items) do
			assert(item.cwd == cwd, item.cwd)
			assert(item.artifact_dir == nil and item.artifact_source == nil)
		end
		assert(items[1].refusal == nil and items[2].refusal == nil)
		assert(items[3].refusal:find("requires a forked task", 1, true))
		local notified
		vim.notify = function(message, level) notified = { message, level } end
		package.loaded["neoterm.terms"] = { start = function() error("Refused steps must not start") end }
		commands.run(items[3])
		assert(notified[1] == items[3].refusal and notified[2] == vim.log.levels.ERROR)
		vim.fn.writefile({ "---", "fork: maybe", "---", "task" }, source)
		assert(not pcall(definitions))
		vim.fn.writefile({ "task" }, source)
		for _, invalid in ipairs({
			{ name = "fork", source = "task.md", fork = true, command = "echo" },
			{ name = "fork", source = "task.md", fork = false, command = "echo" },
			{ name = "requires", source = "task.md", requires_fork = "yes", command = "echo" },
		}) do
			assert(not pcall(commands.for_file, { cwd = cwd, file = source, steps = { invalid } }))
		end
	]])
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
		require("neoterm.terms.artifacts.tasks").executables = function() return {} end
		local definitions = require("neoterm.terms.artifacts.commands").for_file({
			cwd = cwd,
			file = source,
			steps = {
				{ name = "fork", source = "task.md", command = { tag = "open" } },
				{ name = "variant", source = "task.md", variants = { "a" }, command = { cmd = { "git", "commit", "-m", "{message}" } } },
			},
		})
		result = vim.tbl_map(function(item) return vim.fs.relpath(projects, item.cwd) end, definitions)
		assert(vim.deep_equal(definitions[2].cmd, { "git", "commit", "-m", "fix(stores): provider-store" }))
	]])
	local branch = "utils-mono/" .. child.lua_get([[require("neoterm.helpers.hash")("stores")]]) .. "-fix-provider-store"
	assert.same({ branch, branch }, child.lua_get("result"))
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
		local folder = vim.fs.joinpath(artifacts, "sample", "scope", "feature")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(folder, "p")
		local task = vim.fs.joinpath(folder, "task.md")
		local plan = vim.fs.joinpath(folder, "plan.md")
		vim.fn.writefile({ "task" }, task)
		package.loaded["neoterm.config"] = {
			dirs = { projects = vim.fs.joinpath(root, "projects"), artifacts = artifacts },
			default_branches = { "main" },
		}
		require("neoterm.terms.artifacts.tasks").executables = function() return {} end
		local commands = require("neoterm.terms.artifacts.commands")
		local step = {
			name = "implement",
			source = { "task.md", "plan.md" },
			target = { "walkthrough.md", "done.md" },
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
			local branch = require("neoterm.terms.artifacts.paths").source(task).branch
			assert(items[1].cwd == vim.fs.joinpath(root, "projects", "sample", branch))
		end
		check(task, task)
		vim.fn.writefile({ "plan" }, plan)
		check(task, plan)
		check(plan, plan)
		local paths = require("neoterm.terms.artifacts.paths")
		assert(#paths.branches(paths.source(plan)) == 1)
		for _, target in ipairs(step.target) do
			local path = vim.fs.joinpath(folder, target)
			vim.fn.writefile({ "done" }, path)
			assert(#definitions(task) == 0)
			package.loaded["neoterm.config"].steps = {
				vim.tbl_extend("force", step, { command = { tag = "agent", prompt = "implement" } }),
			}
			package.loaded["neoterm.terms.artifacts.cwd"] = { context_dir = function() return cwd end }
			vim.api.nvim_buf_set_name(0, task)
			local selections = 0
			vim.ui.select = function(items)
				selections = selections + 1
				assert(#items == 1)
				assert(items[1].resume == true)
				assert(items[1].artifact_source == plan)
				assert(items[1].prompt == nil)
			end
			commands.select_for_current_file(true)
			assert(selections == 1)
			vim.fn.delete(path)
		end
		vim.fn.delete(plan)
		check(task, task)
		assert(type(step.source) == "table" and type(step.target) == "table")
	]])
end

T["steps without a source accept any artifact and respect targets"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local cwd = vim.fs.joinpath(projects, "sample", "main")
		local folder = vim.fs.joinpath(artifacts, "sample", "scope", "feature")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(folder, "p")
		local step = { name = "diff", target = "merge.txt" }
		package.loaded["neoterm.config"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main" },
			steps = { step },
		}
		require("neoterm.terms.artifacts.tasks").executables = function() return {} end
		local commands = require("neoterm.terms.artifacts.commands")
		local paths = require("neoterm.terms.artifacts.paths")
		for _, name in ipairs({ "task.md", "plan.md", "custom.txt" }) do
			local source = vim.fs.joinpath(folder, name)
			vim.fn.writefile({ "artifact" }, source)
			local function definitions()
				return commands.for_file({ cwd = cwd, file = source, steps = { step } })
			end
			local items = definitions()
			assert(#items == 1)
			assert(items[1].artifact_source == source)
			local branch = paths.source(source).branch
			assert(items[1].cwd == vim.fs.joinpath(projects, "sample", branch))
			assert(vim.tbl_contains(paths.branches(paths.source(source)), branch))
			local target = vim.fs.joinpath(folder, "merge.txt")
			vim.fn.writefile({ "merged" }, target)
			assert(#definitions() == 0)
			vim.fn.delete(target)
		end
		assert(step.source == nil)
	]])
end

T["steps with a status are disabled while the task status precedes it"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local cwd = vim.fs.joinpath(projects, "sample", "main")
		local folder = vim.fs.joinpath(artifacts, "sample", "feature")
		vim.fn.mkdir(cwd, "p")
		vim.fn.mkdir(folder, "p")
		local task = vim.fs.joinpath(folder, "task.md")
		local plan = vim.fs.joinpath(folder, "plan.md")
		local flat = vim.fs.joinpath(folder, "other.task.md")
		vim.fn.writefile({ "task" }, task)
		vim.fn.writefile({ "plan" }, plan)
		vim.fn.writefile({ "flat" }, flat)
		package.loaded["neoterm.config"] = {
			dirs = { projects = projects, artifacts = artifacts },
			default_branches = { "main" },
			tasks = { status = { { name = "inbox" }, { name = "ready" }, { name = "done" } } },
		}
		local statuses = {}
		package.loaded["neoterm.terms.artifacts.tasks"] = {
			executables = function() return {} end,
			status = function(path) return statuses[path] end,
			fork = function() return true end,
		}
		local commands = require("neoterm.terms.artifacts.commands")
		local step = { name = "implement", source = { "task.md", "plan.md" }, status = "ready", command = { cmd = "echo" } }
		local function count(file)
			return #commands.for_file({ cwd = cwd, file = file, steps = { step } })
		end
		assert(count(task) == 1)
		statuses[task] = "inbox"
		assert(count(task) == 0)
		assert(count(plan) == 0)
		statuses[task] = "ready"
		assert(count(plan) == 1)
		statuses[task] = "done"
		assert(count(plan) == 1)
		statuses[task] = "ERROR:INDIRECT"
		assert(count(plan) == 1)
		local flat_step = { name = "flat", source = "task.md", status = "ready", command = { cmd = "echo" } }
		statuses[flat] = "inbox"
		assert(#commands.for_file({ cwd = cwd, file = flat, steps = { flat_step } }) == 0)
		statuses[flat] = "ready"
		assert(#commands.for_file({ cwd = cwd, file = flat, steps = { flat_step } }) == 1)
		local ok = pcall(commands.for_file, {
			cwd = cwd,
			file = task,
			steps = { { name = "invalid", source = "task.md", status = "unknown" } },
		})
		assert(not ok, "Unknown step status should fail validation")
	]])
end

return T
