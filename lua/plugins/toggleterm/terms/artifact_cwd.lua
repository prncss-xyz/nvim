local M = {}

local parameters = require("my.parameters")
local dirs = parameters.dirs

local function is_directory(path)
	local stat = vim.uv.fs_stat(path)
	return stat ~= nil and stat.type == "directory"
end

---@param filename string
---@return boolean
function M.contains(filename)
	return vim.fs.relpath(dirs.artifacts, vim.fs.abspath(filename)) ~= nil
end

--- Resolve the project checkout for a file in the shared artifact directory.
--- Artifact paths are <project>/<branch>/....
--- Prefer an existing branch checkout, then main, then master, then <project>.
---@param filename string
---@return string|nil
function M.resolve(filename)
	local relative = vim.fs.relpath(dirs.artifacts, vim.fs.abspath(filename))
	if relative == nil then
		return nil
	end

	local parts = vim.split(relative, "/", { plain = true, trimempty = true })
	local project = parts[1]
	if project == nil then
		return nil
	end

	local project_dir = vim.fs.joinpath(dirs.projects, project)
	local branch_dir = parts[2] and vim.fs.joinpath(project_dir, parts[2]) or nil
	if branch_dir and is_directory(branch_dir) then
		return branch_dir
	end

	for _, branch in ipairs(parameters.default_branches or { "main", "master" }) do
		local default_dir = vim.fs.joinpath(project_dir, branch)
		if is_directory(default_dir) then
			return default_dir
		end
	end
	if is_directory(project_dir) then
		return project_dir
	end
end

---@return string|nil
function M.context_dir()
	local dir = M.resolve(vim.api.nvim_buf_get_name(0))
	if dir then
		return dir
	end
	if vim.bo.buftype == "terminal" then
		local _, term = require("toggleterm.terminal").identify()
		return term and term.dir or nil
	end
end

---@param project_dir string
---@return string
function M.branch_artifacts(project_dir)
	local project_path = assert(vim.fs.relpath(dirs.projects, vim.fs.abspath(project_dir)), "Project is outside projects directory")
	local project = assert(vim.split(project_path, "/", { plain = true, trimempty = true })[1], "Project name not found")
	local branch = vim.trim(vim.fn.system({ "git", "-C", project_dir, "branch", "--show-current" }))
	assert(vim.v.shell_error == 0 and branch ~= "", "Failed to determine current Git branch")
	local artifact_branch = branch:gsub("/", "-")
	return vim.fs.joinpath(dirs.artifacts, project, artifact_branch)
end

---@param project_dir string
---@return string|nil
function M.project_artifacts(project_dir)
	local matches = vim.fs.find(".artifacts", { path = project_dir, upward = true, limit = 1 })
	local path = matches[1]
	if path == nil then
		return nil
	end
	path = vim.uv.fs_realpath(path)
	if path and M.contains(path) then
		return path
	end
end

---@param path string
---@return string|nil
function M.project_file(path)
	local project_dir = M.resolve(path)
	if project_dir == nil then
		return nil
	end
	return require("my.project_file").find(project_dir, { vim.fs.joinpath(project_dir, ".artifacts") })
end

return M
