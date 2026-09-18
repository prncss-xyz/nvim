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

T["creates tasks for sources without targets"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local projects = vim.fs.joinpath(root, "projects")
		vim.env.HOME = root
		local task_dir = vim.fs.joinpath(artifacts, "nvim", "feat-one", "tasks")
		local done_dir = vim.fs.joinpath(artifacts, "nvim", "feat-two")
		vim.fn.mkdir(task_dir, "p")
		vim.fn.mkdir(done_dir, "p")
		vim.fn.mkdir(vim.fs.joinpath(projects, "nvim", "main"), "p")
		local other_task_dir = vim.fs.joinpath(artifacts, "other", "feat-other", "tasks")
		vim.fn.mkdir(other_task_dir, "p")
		vim.fn.writefile({ "task" }, vim.fs.joinpath(other_task_dir, "task.md"))
		local source = vim.fs.joinpath(task_dir, "task.md")
		vim.fn.writefile({ "task" }, source)
		vim.fn.writefile({ "task" }, vim.fs.joinpath(done_dir, "task.md"))
		vim.fn.writefile({ "done" }, vim.fs.joinpath(done_dir, "design.md"))
		package.loaded["my.parameters"] = {
			dirs = { artifacts = artifacts, projects = projects },
			default_branches = { "main", "master" },
		}
		package.loaded["plugins.toggleterm.templates.artifacts"] = nil
		local definitions
		require("plugins.toggleterm.templates.artifacts").generator({
			dir = vim.fs.joinpath(projects, "nvim", "main"),
			tasks = {
				{
					name = "design",
					source = "task.md",
					target = "design.md",
					cmd = "pi {source} {target}",
					on_exit = "keep",
					auto_scroll = false,
				},
			},
		}, function(value) definitions = value end)
		vim.wait(1000, function() return definitions ~= nil end)
		local built = definitions[1].builder()
		result = {
			count = #definitions,
			name = definitions[1].name,
			cmd = built.cmd,
			cwd = built.cwd,
			on_exit = built.on_exit,
			auto_scroll = built.auto_scroll,
			metadata_removed = built.name == nil and built.source == nil and built.target == nil,
		}
		local cwd = vim.fs.joinpath(projects, "nvim", "main")
		expected = {
			count = 1,
			name = "design:feat-one:tasks",
			cmd = "pi \"~/artifacts/nvim/feat-one/tasks/task.md\" \"~/artifacts/nvim/feat-one/tasks/design.md\"",
			cwd = cwd,
			on_exit = "keep",
			auto_scroll = false,
			metadata_removed = true,
		}
	]])

	assert.same(child.lua_get("expected"), child.lua_get("result"))
end

T["creates tasks for executable artifact scripts"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local projects = vim.fs.joinpath(root, "projects")
		local project = vim.fs.joinpath(projects, "notes", "main")
		local script_dir = vim.fs.joinpath(artifacts, "nvim", "neomux", "task")
		vim.fn.mkdir(project, "p")
		vim.fn.mkdir(script_dir, "p")
		local task = vim.fs.joinpath(script_dir, "task.md")
		local script = vim.fs.joinpath(script_dir, "review")
		local regular = vim.fs.joinpath(script_dir, "notes")
		vim.fn.writefile({ "task" }, task)
		vim.fn.writefile({ "#!/bin/sh", "echo review" }, script)
		vim.fn.writefile({ "notes" }, regular)
		vim.uv.fs_chmod(script, 493)
		package.loaded["my.parameters"] = {
			dirs = { artifacts = artifacts, projects = projects },
			default_branches = { "main", "master" },
		}
		package.loaded["plugins.toggleterm.terms.artifact_cwd"] = nil
		package.loaded["plugins.toggleterm.templates.artifacts"] = nil
		local definitions, artifact_definitions
		local template = require("plugins.toggleterm.templates.artifacts")
		template.generator({
			dir = project,
			file = task,
			tasks = {},
		}, function(value) definitions = value end)
		template.generator({
			dir = script_dir,
			file = "",
			tasks = {},
		}, function(value) artifact_definitions = value end)
		vim.wait(1000, function() return definitions ~= nil and artifact_definitions ~= nil end)
		local built = definitions[1].builder()
		local artifact_built = artifact_definitions[1].builder()
		result = {
			count = #definitions,
			name = definitions[1].name,
			cmd = built.cmd,
			cwd = built.cwd,
			on_exit = built.on_exit,
			artifact_count = #artifact_definitions,
			artifact_name = artifact_definitions[1].name,
			artifact_cwd = artifact_built.cwd,
		}
		expected = {
			count = 1,
			name = "artifact review",
			cmd = { script },
			cwd = project,
			on_exit = "keep",
			artifact_count = 1,
			artifact_name = "artifact review",
			artifact_cwd = script_dir,
		}
	]])

	assert.same(child.lua_get("expected"), child.lua_get("result"))
end

T["supports flat sources without a target"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local projects = vim.fs.joinpath(root, "projects")
		vim.fn.mkdir(vim.fs.joinpath(artifacts, "nvim"), "p")
		vim.fn.mkdir(vim.fs.joinpath(projects, "nvim", "main"), "p")
		local source = vim.fs.joinpath(artifacts, "nvim", "feat-flat.task.md")
		local nested_source = vim.fs.joinpath(artifacts, "nvim", "neomux", "fix-pnpm-template.task.md")
		vim.fn.mkdir(vim.fs.dirname(nested_source), "p")
		vim.fn.writefile({ "task" }, source)
		vim.fn.writefile({ "task" }, nested_source)
		package.loaded["my.parameters"] = {
			dirs = { artifacts = artifacts, projects = projects },
			default_branches = { "main", "master" },
		}
		package.loaded["plugins.toggleterm.templates.artifacts"] = nil
		local template = require("plugins.toggleterm.templates.artifacts")
		local definitions, invalid
		template.generator({
			dir = vim.fs.joinpath(projects, "nvim", "main"),
			tasks = { { name = "run", source = "task.md", cmd = "pi {source}" } },
		}, function(value) definitions = value end)
		template.generator({
			dir = vim.fs.joinpath(projects, "nvim", "main"),
			tasks = { { name = "bad", source = "task.md", cmd = "pi {target}" } },
		}, function(value) invalid = value end)
		vim.wait(1000, function() return definitions ~= nil and invalid ~= nil end)
		local built = definitions[1].builder()
		local ok, err = pcall(invalid[1].builder)
		result = {
			count = #definitions,
			name = definitions[1].name,
			nested_name = definitions[2].name,
			cmd = built.cmd,
			target_error = not ok and err:find("references {target}", 1, true) ~= nil,
		}
		expected = {
			count = 2,
			name = "run:feat-flat:feat-flat",
			nested_name = "run:neomux:fix-pnpm-template",
			cmd = "pi \"" .. source .. "\"",
			target_error = true,
		}
	]])

	assert.same(child.lua_get("expected"), child.lua_get("result"))
end

T["filters non-default branches and resolves fork cwd"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local projects = vim.fs.joinpath(root, "projects")
		local current = vim.fs.joinpath(projects, "nvim", "feat-one")
		for _, branch in ipairs({ "feat-one", "feat-two" }) do
			local dir = vim.fs.joinpath(artifacts, "nvim", branch)
			vim.fn.mkdir(dir, "p")
			vim.fn.writefile({ "task" }, vim.fs.joinpath(dir, "task.md"))
		end
		package.loaded["my.parameters"] = {
			dirs = { artifacts = artifacts, projects = projects },
			default_branches = { "main", "master" },
		}
		vim.system = function(_, _, callback)
			vim.schedule(function() callback({ code = 0, stdout = "feat-one\n" }) end)
		end
		package.loaded["plugins.toggleterm.templates.artifacts"] = nil
		local template = require("plugins.toggleterm.templates.artifacts")
		local forked, local_task
		template.generator({
			dir = current,
			tasks = { { name = "forked", source = "task.md", cmd = "run", fork = true } },
		}, function(value) forked = value end)
		template.generator({
			dir = current,
			tasks = { { name = "local", source = "task.md", cmd = "run", fork = false } },
		}, function(value) local_task = value end)
		vim.wait(1000, function() return forked ~= nil and local_task ~= nil end)
		result = {
			forked_count = #forked,
			forked_name = forked[1].name,
			forked_cwd_matches = forked[1].builder().cwd == current,
			local_count = #local_task,
			local_cwd_matches = local_task[1].builder().cwd == current,
		}
	]])

	assert.same({
		forked_count = 1,
		forked_name = "forked:feat-one:feat-one",
		forked_cwd_matches = true,
		local_count = 1,
		local_cwd_matches = true,
	}, child.lua_get("result"))
end

return T
