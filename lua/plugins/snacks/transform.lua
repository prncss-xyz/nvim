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

function M.filter_current_dir()
	local cwd = vim.fn.getcwd()
	return function(item)
		local path = Snacks.picker.util.path(item)
		return path ~= cwd
	end
end

return M
