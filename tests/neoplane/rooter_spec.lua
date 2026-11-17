local MiniTest = require("mini.test")

local T = MiniTest.new_set()

T["zone follows file roots and artifact checkouts, notifying only on changes"] = function()
	local original_dir = vim.fn.getcwd()
	local original_config = package.loaded["neoplane.config"]
	local original_artifacts = package.loaded["neoplane.terms.artifacts.cwd"]
	local original_rooter = package.loaded["neoplane.rooter"]
	local original_buf = vim.api.nvim_get_current_buf()
	local dir = vim.fn.tempname()
	local project = dir .. "/project"
	local other = dir .. "/other"
	local artifact = dir .. "/artifacts/task.md"
	vim.fn.mkdir(project .. "/.git", "p")
	vim.fn.mkdir(other, "p")
	vim.fn.mkdir(dir .. "/artifacts", "p")
	local zones = {}
	package.loaded["neoplane.config"] = {
		rooter_patterns = { ".git" },
		on_zone = function(zone)
			table.insert(zones, zone)
		end,
	}
	package.loaded["neoplane.terms.artifacts.cwd"] = {
		resolve = function(path)
			return path == artifact and project or nil
		end,
	}
	package.loaded["neoplane.rooter"] = nil
	local rooter = require("neoplane.rooter")
	local bufs = {}
	local by_path = {}
	local function enter(path)
		local buf = by_path[path]
		if not buf then
			buf = vim.api.nvim_create_buf(true, false)
			vim.api.nvim_buf_set_name(buf, path)
			by_path[path] = buf
			table.insert(bufs, buf)
		end
		vim.api.nvim_set_current_buf(buf)
		rooter.on_buf_enter()
	end
	local ok, err = pcall(function()
		enter(project .. "/one.txt")
		enter(project .. "/two.txt")
		enter(artifact)
		enter(other .. "/file.txt")
		enter(artifact)
		assert.same({ project, other, project }, zones)
	end)
	vim.api.nvim_set_current_buf(original_buf)
	vim.api.nvim_set_current_dir(original_dir)
	for _, buf in ipairs(bufs) do
		vim.api.nvim_buf_delete(buf, { force = true })
	end
	package.loaded["neoplane.config"] = original_config
	package.loaded["neoplane.terms.artifacts.cwd"] = original_artifacts
	package.loaded["neoplane.rooter"] = original_rooter
	vim.fn.delete(dir, "rf")
	if not ok then
		error(err)
	end
end

return T
