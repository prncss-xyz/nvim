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

T["discovers packages two levels deep without workspaces"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		local function package(path, scripts)
			vim.fn.mkdir(path, "p")
			vim.fn.writefile({ vim.json.encode({ scripts = scripts }) }, vim.fs.joinpath(path, "package.json"))
		end
		vim.fn.mkdir(root, "p")
		vim.fn.writefile({ vim.json.encode({ name = "root", packageManager = "pnpm@10", scripts = { root = "root" } }) }, vim.fs.joinpath(root, "package.json"))
		package(vim.fs.joinpath(root, "packages", "one"), { test = "test" })
		package(vim.fs.joinpath(root, "tools"), { build = "build" })
		package(vim.fs.joinpath(root, "packages", "one", "deep"), { ignored = "ignored" })
		package(vim.fs.joinpath(root, "node_modules", "dependency"), { ignored = "ignored" })
		package(vim.fs.joinpath(root, ".hidden"), { ignored = "ignored" })
		vim.fn.executable = function() return 1 end
		local definitions = require("plugins.toggleterm.templates.npm").generator({ dir = root })
		result = vim.tbl_map(function(definition) return definition.name end, definitions)
		table.sort(result)
	]])

	assert.same({
		"pnpm install",
		"pnpm root (root)",
		"pnpm[packages/one] test",
		"pnpm[tools] build",
	}, child.lua_get("result"))
end

T["searches upward at most two levels without falling back to nvim cwd"] = function()
	child.lua([[
		local root = vim.fn.tempname()
		vim.fn.mkdir(vim.fs.joinpath(root, "one", "two", "three"), "p")
		vim.fn.writefile({ vim.json.encode({ name = "root", packageManager = "pnpm@10", scripts = { test = "test" } }) }, vim.fs.joinpath(root, "package.json"))
		vim.fn.executable = function() return 1 end
		local npm = require("plugins.toggleterm.templates.npm")
		local found = npm.generator({ dir = vim.fs.joinpath(root, "one", "two") })
		local missing = npm.generator({ dir = vim.fs.joinpath(root, "one", "two", "three") })
		result = {
			found = type(found) == "table" and found[1].name,
			missing = missing,
		}
	]])

	assert.same({
		found = "pnpm test (root)",
		missing = "No package.json file found",
	}, child.lua_get("result"))
end

return T
