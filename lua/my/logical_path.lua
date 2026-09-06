local M = {}

local function normalize(path)
	local normalized = vim.fs.normalize(path)
	return normalized ~= "/" and normalized:gsub("/+$", "") or normalized
end

local function descendant_path(cwd, target)
	if target == cwd then
		return ""
	end

	local prefix = cwd == "/" and cwd or cwd .. "/"
	if target:sub(1, #prefix) ~= prefix then
		return nil
	end

	local relative = target:sub(#prefix + 1)
	if relative == ".." or relative:sub(1, 3) == "../" then
		return nil
	end
	return relative
end

local function symlink_target_in(cwd, target)
	local realpath_by_link = {}
	local ok, matches = pcall(vim.fs.find, function(name, parent)
		local link = vim.fs.joinpath(parent, name)
		local metadata_ok, metadata = pcall(vim.uv.fs_lstat, link)
		if not metadata_ok or not metadata or metadata.type ~= "link" then
			return false
		end

		local realpath_ok, realpath = pcall(vim.uv.fs_realpath, link)
		if not realpath_ok or not realpath then
			return false
		end
		realpath = normalize(realpath)
		realpath_by_link[link] = realpath
		return target == realpath or target:sub(1, #realpath + 1) == realpath .. "/"
	end, { path = cwd, limit = 1 })

	local link = ok and matches[1] or nil
	if not link then
		return nil
	end
	return link, realpath_by_link[link]
end

local function descendant_contains_symlink(cwd, relative)
	local path = cwd
	for component in relative:gmatch("[^/]+") do
		path = vim.fs.joinpath(path, component)
		local ok, metadata = pcall(vim.uv.fs_lstat, path)
		if not ok then
			return false
		end
		if metadata and metadata.type == "link" then
			return true
		end
	end
	return false
end

function M.capture(bufnr)
	bufnr = bufnr or 0
	if vim.b[bufnr].my_logical_cwd ~= nil then
		return vim.b[bufnr].my_logical_cwd
	end

	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" or name:sub(1, 1) ~= "/" then
		return nil
	end

	local cwd = normalize(vim.fn.getcwd())
	local target = normalize(name)
	local relative = descendant_path(cwd, target)
	if (relative ~= nil and descendant_contains_symlink(cwd, relative))
		or (relative == nil and symlink_target_in(cwd, target) ~= nil)
	then
		vim.b[bufnr].my_logical_cwd = cwd
		return cwd
	end
	return nil
end

function M.cwd(bufnr)
	return vim.b[bufnr or 0].my_logical_cwd
end

function M.resolve(bufnr, path)
	local cwd = M.cwd(bufnr)
	if cwd == nil or path:sub(1, 1) ~= "/" then
		return path
	end

	local link, target = symlink_target_in(cwd, normalize(path))
	if not link then
		return path
	end
	return link .. path:sub(#target + 1)
end

return M
