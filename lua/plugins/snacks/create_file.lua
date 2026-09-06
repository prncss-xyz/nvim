local M = {}

---@param picker snacks.Picker
---@return string
function M.path(picker)
	assert(picker.opts.format == "file", "picker does not select files")

	local name = vim.trim(picker.input.filter.pattern)
	assert(name ~= "", "file name is empty")

	return vim.fs.normalize(vim.fs.joinpath(picker:cwd(), name))
end

---@param picker snacks.Picker
function M.use_focused_path(picker)
	local item = assert(picker:current(), "picker has no focused entry")
	local path = assert(item.file, "focused entry has no file path")
	local is_absolute = path:sub(1, 1) == "/"
	if item.cwd or is_absolute then
		local absolute_path = vim.fs.normalize(is_absolute and path or vim.fs.joinpath(item.cwd, path))
		path = assert(vim.fs.relpath(picker:cwd(), absolute_path), "focused entry is outside the picker cwd")
	end
	local directory = path:match("^(.*)/[^/]+$") or ""
	picker.input:set(directory == "" and "" or directory:gsub("/+$", "") .. "/")
end

---@param picker snacks.Picker
function M.create(picker)
	local path = M.path(picker)
	picker:close()
	require("my.create").create(path)
end

return M
