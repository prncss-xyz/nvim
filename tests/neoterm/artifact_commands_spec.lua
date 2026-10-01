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
		local definitions = require("neoterm.terms.artifacts.commands").for_file({
			cwd = cwd,
			file = source,
			steps = {
				{ name = "var", source = "task.md", variants = { "a", "b" }, command = { cmd = "echo {variant}", title = "{step}" } },
				{ name = "fn", source = "task.md", variants = { "a", "b" }, command = function(vars)
					return { cmd = vars.variant .. " " .. vars.step }
				end },
			},
		})
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

return T
