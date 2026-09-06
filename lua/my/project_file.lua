local M = {}

local function is_inside(path, dir)
	local relative = vim.fs.relpath(dir, path)
	return relative ~= nil and relative ~= "." and not relative:match("^%.%.[/\\]")
end

local function contains(path, parent)
	return path == parent or is_inside(path, parent)
end

local function get_test(dir, exclude)
	local excluded = vim.tbl_map(vim.fs.normalize, exclude or {})
	return function(path)
		if path == "" then
			return false
		end
		path = vim.fs.normalize(vim.fn.expand(path))
		if not is_inside(path, dir) or vim.fn.filereadable(path) ~= 1 then
			return false
		end
		for _, excluded_path in ipairs(excluded) do
			if contains(path, excluded_path) then
				return false
			end
		end
		return true, path
	end
end

local function first_matching(paths, test)
	for _, path in ipairs(paths) do
		local matches, normalized = test(path)
		if matches then
			return normalized
		end
	end
end

---@param dir string
---@param exclude? string[]
---@return string?
function M.find(dir, exclude)
	dir = vim.fs.normalize(dir)
	local test = get_test(dir, exclude)
	local jumplist = vim.fn.getjumplist()[1]
	local seen = {}
	for i = #jumplist, 1, -1 do
		local bufnr = jumplist[i].bufnr
		if not seen[bufnr] then
			seen[bufnr] = true
			local matches, path = test(vim.api.nvim_buf_get_name(bufnr))
			if matches then
				return path
			end
		end
	end

	local oldfile = first_matching(vim.v.oldfiles, test)
	if oldfile then
		return oldfile
	end

	if vim.uv.fs_stat(vim.fs.joinpath(dir, ".git")) then
		for _, args in ipairs({
			{ "diff", "--name-only" },
			{ "diff", "--cached", "--name-only" },
			{ "ls-files" },
		}) do
			local command = { "git", "-C", dir }
			vim.list_extend(command, args)
			local paths = vim.tbl_map(function(path)
				return vim.fs.joinpath(dir, path)
			end, vim.fn.systemlist(command))
			local match = first_matching(paths, test)
			if match then
				return match
			end
		end
	end

	local readme = vim.fs.joinpath(dir, "README.md")
	if vim.fn.filereadable(readme) == 1 then
		return readme
	end
end

return M
