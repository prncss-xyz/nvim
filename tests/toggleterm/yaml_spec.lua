local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua(
				[[package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
				package.loaded["plugins.toggleterm.config"] = {
					yaml = {
						decode = function(text) return { source = text } end,
						encode = function(value) return "title: " .. value.title end,
					},
				}
			]]
			)
		end,
		post_once = child.stop,
	},
})

T["reads frontmatter from the start of a buffer"] = function()
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { "---", "title: Example", "---", "Body" })
		local value = require("plugins.toggleterm.yaml").read(0)
		assert(vim.deep_equal(value, { source = "title: Example" }))]])
end

T["returns nil when frontmatter is absent"] = function()
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Heading", "---" })
		assert(require("plugins.toggleterm.yaml").read(0) == nil)]])
end

T["replaces existing frontmatter without changing the body"] = function()
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { "---", "title: Old", "---", "Body" })
		require("plugins.toggleterm.yaml").write(0, { title = "New" })
		assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
			"---", "title: New", "---", "Body",
		}))]])
end

T["inserts frontmatter before an existing document"] = function()
	child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, { "# Heading" })
		require("plugins.toggleterm.yaml").write(0, { title = "New" })
		assert(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {
			"---", "title: New", "---", "", "# Heading",
		}))]])
end

T["refuses to write frontmatter that is not a YAML mapping"] = function()
	child.lua([[local ok, err = pcall(require("plugins.toggleterm.yaml").write, 0, "title")
		assert(not ok)
		assert(err:find("must be a YAML mapping", 1, true))]])
end

return T
