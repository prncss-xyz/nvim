if not require("my.conds").not_vscode() then
	return
end

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

local function contains_symlink(cwd, relative)
	local path = cwd
	for component in relative:gmatch("[^/]+") do
		path = vim.fs.joinpath(path, component)
		local ok, metadata = pcall(vim.uv.fs_lstat, path)
		if ok and metadata and metadata.type == "link" then
			return true
		end
	end
	return false
end

local function resolved_through_cwd_symlink(cwd, target)
	local ok, matches = pcall(vim.fs.find, function(name, path)
		local link_path = vim.fs.joinpath(path, name)
		local metadata_ok, metadata = pcall(vim.uv.fs_lstat, link_path)
		if not metadata_ok or not metadata or metadata.type ~= "link" then
			return false
		end

		local realpath_ok, realpath = pcall(vim.uv.fs_realpath, link_path)
		if not realpath_ok or not realpath then
			return false
		end
		realpath = normalize(realpath)
		return target == realpath or target:sub(1, #realpath + 1) == realpath .. "/"
	end, { path = cwd, limit = 1 })
	return ok and #matches > 0
end

local function capture_symlink_cwd()
	if vim.b.my_rooter_symlink_cwd ~= nil then
		return
	end

	local name = vim.api.nvim_buf_get_name(0)
	if name == "" or name:sub(1, 1) ~= "/" then
		return
	end

	local cwd = normalize(vim.fn.getcwd())
	local target = normalize(name)
	local relative = descendant_path(cwd, target)
	local has_symlink = relative ~= nil and contains_symlink(cwd, relative)
	if has_symlink or (relative == nil and resolved_through_cwd_symlink(cwd, target)) then
		vim.b.my_rooter_symlink_cwd = cwd
	end
end

local group = vim.api.nvim_create_augroup("MyRooter", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter" }, {
	group = group,
	nested = true,
	callback = function()
		if vim.bo.buftype ~= "" then
			return
		end

		capture_symlink_cwd()
		local root = vim.b.my_rooter_symlink_cwd
		if root == nil then
			root = vim.fs.root(0, require("my.parameters").rooter_patterns)
		end
		if root then
			vim.api.nvim_set_current_dir(root)
			require("plugins.toggleterm.terms").on_dir()
		end
	end,
})
