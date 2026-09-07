local M = {}

local function get_snip(target)
	local rel = vim.fn.fnamemodify(target, ":.")
	local snips = require("my.create.snips")
	for _, entry in ipairs(snips) do
		if rel:match(entry.pattern) then
			return entry.fn
		end
	end
end

function M.create(target)
	local snippet = get_snip(target)
	local exists = vim.fn.filereadable(target) == 1
	vim.cmd.edit(target)
	if not exists and snippet then
		local luasnip = require("luasnip")
		vim.cmd.startinsert()
		luasnip.snip_expand(luasnip.snippet("", snippet()), {})
	end
end

function M.artifact_index()
	local current = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
	local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
	local project_dir = artifact_cwd.resolve(current) or assert(vim.uv.fs_realpath(vim.fn.getcwd()))
	local dirs = require("my.parameters").dirs
	local project_path = assert(vim.fs.relpath(dirs.projects, project_dir))
	local project_name = assert(vim.split(project_path, "/", { plain = true, trimempty = true })[1])
	local artifact_dir = vim.fs.joinpath(dirs.artifacts, project_name)
	local target = vim.fs.joinpath(artifact_dir, "index.md")

	if current == target then
		require("plugins.toggleterm.terms.ensure_dir").ensure_dir_excluding(project_dir, { artifact_dir })
		return
	end

	vim.fn.mkdir(artifact_dir, "p")
	M.create(vim.fn.fnameescape(target))
end

return M
