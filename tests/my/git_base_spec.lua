local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				vim.opt.rtp:prepend(vim.fn.getcwd())
				vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/gitsigns.nvim")
				root = vim.fn.tempname()
				vim.fn.mkdir(root, "p")
				local function git(...)
					local command = { "git", "-C", root }
					vim.list_extend(command, { ... })
					local result = vim.system(command):wait()
					assert(result.code == 0, result.stderr)
				end
				git("init", "-b", "main")
				vim.fn.writefile({ "original" }, root .. "/file.lua")
				vim.fn.writefile({ "original" }, root .. "/other.lua")
				git("add", ".")
				git("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m", "base")
				git("checkout", "-b", "feature")
				vim.fn.writefile({ "changed" }, root .. "/file.lua")
				vim.fn.writefile({ "changed" }, root .. "/other.lua")
				git("add", ".")
				git("-c", "user.name=Test", "-c", "user.email=test@example.com", "commit", "-m", "feature")
				base = require("my.git_base")
				gs = require("gitsigns")
				gs.setup({ on_attach = base.on_attach })
				function open(name)
					vim.cmd.edit(root .. "/" .. (name or "file.lua"))
					return vim.api.nvim_get_current_buf()
				end
				function expect_hunks(buf, count)
					assert(vim.wait(3000, function()
						local hunks = gs.get_hunks(buf)
						return hunks and #hunks == count
					end), "Expected " .. count .. " hunks")
				end
			]])
		end,
		post_case = function()
			child.lua([[gs.detach_all(); vim.fn.delete(root, "rf")]])
		end,
		post_once = child.stop,
	},
})

T["base selected during attachment shows committed branch changes"] = function()
	child.lua([[
		local buf = open()
		base.set(root, "main")
		expect_hunks(buf, 1)
	]])
end

T["base selected before opening applies to subsequent buffers"] = function()
	child.lua([[
		base.set(root, "main")
		expect_hunks(open(), 1)
		expect_hunks(open("other.lua"), 1)
	]])
end

T["attached buffers change base and reset to the index"] = function()
	child.lua([[
		local buf = open()
		expect_hunks(buf, 0)
		base.set(root, "main")
		expect_hunks(buf, 1)
		base.set(root, "HEAD")
		expect_hunks(buf, 0)
	]])
end

T["latest selection wins while attachment is pending"] = function()
	child.lua([[
		local buf = open()
		base.set(root, "main")
		base.set(root, "HEAD")
		expect_hunks(buf, 0)
		vim.wait(100)
		assert(#gs.get_hunks(buf) == 0)
	]])
end

return T
