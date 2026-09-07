local M = {}
local window = require("plugins.toggleterm.terms.window")

local function project_dir()
	local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
	local current = vim.api.nvim_buf_get_name(0)
	local dir = artifact_cwd.resolve(current)
	if dir then
		return dir
	end
	if vim.bo.buftype == "terminal" then
		local _, term = require("toggleterm.terminal").identify()
		return term and term.dir or vim.fn.getcwd()
	end
	return vim.fn.getcwd()
end

local function latest_buffer(test)
	local latest
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(bufnr)
		local buffer = vim.fn.getbufinfo(bufnr)[1]
		if test(bufnr, name) and (latest == nil or (buffer.lastused or 0) > (latest.lastused or 0)) then
			latest = { bufnr = bufnr, name = name, lastused = buffer.lastused }
		end
	end
	return latest
end

local function latest_artifact(dir)
	local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
	return latest_buffer(function(_, name)
		return artifact_cwd.resolve(name) == dir
	end)
end

local function focus_artifact()
	local target = latest_artifact(project_dir())
	if target == nil or target.bufnr == vim.api.nvim_get_current_buf() then
		return
	end
	vim.cmd.buffer(target.bufnr)
end

local function source_context(dir)
	local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
	local ctx = window.get_ctx()
	if ctx == nil then
		return
	end
	local path = vim.api.nvim_buf_get_name(ctx.bufnr)
	if path == "" or artifact_cwd.contains(path) or vim.fs.relpath(dir, path) == nil then
		return
	end
	return {
		bufnr = ctx.bufnr,
		path = vim.fs.relpath(dir, path) or path,
		row = ctx.row,
		col = ctx.col,
	}
end

local artifact

local function send_to_artifact(str)
	local dir = project_dir()
	local target = latest_artifact(dir)
	if target == nil then
		return
	end
	if type(str) == "function" then
		local ctx = source_context(dir)
		if ctx == nil then
			return
		end
		str = str(ctx, artifact)
	end
	if type(str) ~= "string" then
		return
	end
	vim.fn.bufload(target.bufnr)
	local row, col = unpack(vim.api.nvim_buf_get_mark(target.bufnr, '"'))
	row = math.max(row, 1)
	local line = vim.api.nvim_buf_get_lines(target.bufnr, row - 1, row, false)[1] or ""
	col = math.min(col, #line)
	vim.api.nvim_buf_set_text(target.bufnr, row - 1, col, row - 1, col, vim.split(str, "\n", { plain = true }))
	if target.bufnr ~= vim.api.nvim_get_current_buf() then
		vim.cmd.buffer(target.bufnr)
	end
end

artifact = {
	key = "artifact",
	tag = "agent",
	focus = focus_artifact,
	toggle = function()
		require("my.create").artifact_index()
	end,
	send_str = send_to_artifact,
}
artifact.term = artifact

setmetatable(artifact, {
	__index = function()
		return function() end
	end,
})

function M.from_query(query)
	if query and query.key == "artifact" then
		return artifact
	end
end

return M
