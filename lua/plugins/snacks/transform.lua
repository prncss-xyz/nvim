local M = {}

function M.modified()
	local name = vim.api.nvim_buf_get_name(0)
	return function(item, ctx)
		local path = Snacks.picker.util.path(item)
		local fullpath = vim.fn.fnamemodify(path, ":p")
		return fullpath ~= name and vim.fn.filereadable(path) == 1
	end
end

function M.exclude_current()
	local name = vim.api.nvim_buf_get_name(0)
	return function(item, ctx)
		ctx.meta.done = ctx.meta.done or {} ---@type table<string, boolean>
		local path = Snacks.picker.util.path(item)
		if ctx.meta.done[path] then
			return false
		end
		ctx.meta.done[path] = true
		return path ~= name
	end
end

function M.file()
	local name = vim.api.nvim_buf_get_name(0)
	local cwd = vim.fn.getcwd()
	return function(item, ctx)
		ctx.meta.done = ctx.meta.done or {} ---@type table<string, boolean>
		local path = Snacks.picker.util.path(item)
		if ctx.meta.done[path] then
			return false
		end
		ctx.meta.done[path] = true
		if not vim.startswith(path, cwd) then
			return false
		end
		return path ~= name
	end
end

function M.hunk()
	local name = vim.api.nvim_buf_get_name(0)
	return function(item, ctx)
		item.file = item.text
		ctx.meta.done = ctx.meta.done or {} ---@type table<string, boolean>
		local path = Snacks.picker.util.path(item)
		if ctx.meta.done[path] then
			return false
		end
		ctx.meta.done[path] = true
		return path ~= name
	end
end

function M.filter_current_dir()
	local cwd = vim.fn.getcwd()
	return function(item)
		local path = Snacks.picker.util.path(item)
		return path ~= cwd
	end
end

function M.diff_files(git_status_base)
	Snacks.picker.pick({
		finder = function(opts, ctx)
			return require("snacks.picker.source.proc").proc(
				ctx:opts({
					cmd = git_status_base == "HEAD" and "git" or "sh",
					args = git_status_base == "HEAD"
						and { "ls-files", "-mo", "--exclude-standard" }
						or {
							"-c",
							'git diff --name-only "$1"; git ls-files --others --exclude-standard',
							"sh",
							git_status_base,
						},
					transform = M.hunk(),
				}),
				ctx
			)
		end,
		format = "file",
		title = "Diff Files",
		matcher = {
			cwd_bonus = true,
			frecency = true,
			sort_empty = true,
		},
		transform = M.modified(),
	})
end

return M
