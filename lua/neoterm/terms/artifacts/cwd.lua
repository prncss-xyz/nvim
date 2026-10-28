local M = {}
local config = require("neoterm.config")
local paths = require("neoterm.terms.artifacts.paths")

M.link = paths.link

---@param paths table<string, boolean>
---@return table|nil
function M.latest_file(paths)
	local latest
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local path = vim.api.nvim_buf_get_name(bufnr)
		local info = vim.fn.getbufinfo(bufnr)[1]
		if paths[path] and (latest == nil or (info.lastused or 0) > latest.lastused) then
			latest = { bufnr = bufnr, path = path, lastused = info.lastused or 0 }
		end
	end
	return latest
end

---@param dir string
---@return table|nil
function M.latest_in(dir)
	local paths = {}
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local path = vim.api.nvim_buf_get_name(bufnr)
		if path ~= "" and vim.fn.filereadable(path) == 1 and vim.fs.relpath(dir, vim.fs.abspath(path)) ~= nil then
			paths[path] = true
		end
	end
	return M.latest_file(paths)
end

function M.contains(filename)
	return vim.fs.relpath(config.dirs.artifacts, vim.fs.abspath(filename)) ~= nil
end

function M.resolve_all(filename)
	return paths.checkouts(filename)
end

function M.resolve(filename)
	local checkouts = M.resolve_all(filename)
	if #checkouts == 1 then
		return checkouts[1]
	end
	local current = vim.fn.getcwd()
	for _, checkout in ipairs(checkouts) do
		if vim.fs.relpath(checkout, current) ~= nil then
			return checkout
		end
	end
	local latest, selected
	for _, checkout in ipairs(checkouts) do
		local candidate = M.latest_in(checkout)
		if candidate and (latest == nil or candidate.lastused > latest.lastused) then
			latest, selected = candidate, checkout
		elseif candidate and candidate.lastused == latest.lastused then
			selected = nil
		end
	end
	return selected
end

function M.select_checkout(filename, callback)
	local checkouts = M.resolve_all(filename)
	if #checkouts == 1 then
		return callback(checkouts[1])
	end
	vim.ui.select(checkouts, { prompt = "Select artifact checkout: " }, function(checkout)
		if checkout then
			callback(checkout)
		end
	end)
end

function M.context_dir()
	local file = vim.api.nvim_buf_get_name(0)
	local dir = M.resolve(file)
	if dir then
		return dir
	end
	if M.contains(file) then
		local project = paths.artifact_project(file)
		return project and paths.default_checkout(project) or nil
	end
	if vim.bo.buftype == "terminal" then
		local _, term = require("toggleterm.terminal").identify()
		return term and term.dir or nil
	end
end

function M.artifact_folders(project_dir)
	return paths.artifact_folders(project_dir)
end

function M.select_artifacts(project_dir, callback)
	local folder, available = paths.preferred_folder(project_dir)
	if not available then
		vim.fn.mkdir(folder, "p")
		local index = vim.fs.joinpath(folder, "index.md")
		if vim.fn.filereadable(index) == 0 then
			assert(vim.fn.writefile({}, index) == 0, "Failed to create repo artifact")
		end
	end
	return callback(folder)
end

function M.for_checkout(project_dir)
	return (paths.preferred_folder(project_dir))
end

function M.latest_for_checkout(project_dir, folder)
	local files = {}
	for _, file in ipairs(paths.artifact_files(project_dir)) do
		if folder == nil or vim.fs.relpath(folder, file) ~= nil then
			files[file] = true
		end
	end
	return M.latest_file(files)
end

function M.select_artifact_file(project_dir, folder, callback)
	local files = {}
	for _, file in ipairs(paths.artifact_files(project_dir)) do
		if vim.fs.relpath(folder, file) ~= nil then
			table.insert(files, file)
		end
	end
	if #files == 0 then
		return callback(vim.fs.joinpath(folder, "index.md"))
	end
	if #files == 1 then
		return callback(files[1])
	end
	vim.ui.select(files, {
		prompt = "Select artifact file: ",
		format_item = function(file)
			return assert(vim.fs.relpath(folder, file))
		end,
	}, function(file)
		if file then
			callback(file)
		end
	end)
end

function M.for_project(project_dir)
	return paths.project_artifacts(paths.project(project_dir))
end

function M.project_file(path)
	local project_dir = M.resolve(path)
	if project_dir == nil then
		return nil
	end
	return require("neoterm.helpers.project_file").get_project_file(project_dir)
end

return M
