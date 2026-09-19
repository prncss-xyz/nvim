local M = {}
local window = require("neoterm.terms.window")

local function noop() end

local function project_dir()
	local artifact_cwd = require("neoterm.terms.artifact_cwd")
	local current = vim.api.nvim_buf_get_name(0)
	local dir = artifact_cwd.resolve(current)
		or vim.fs.root(current, require("neoterm.config").rooter_patterns)
		or vim.fn.getcwd()
	dir = vim.uv.fs_realpath(dir) or vim.fs.normalize(dir)
	if vim.fs.relpath(require("neoterm.config").dirs.projects, dir) == nil then
		return nil
	end
	return dir
end

local function latest_artifact(dir)
	if dir == nil then
		return nil
	end
	local artifact_cwd = require("neoterm.terms.artifact_cwd")
	return artifact_cwd.latest_in(artifact_cwd.for_checkout(dir))
end

local function source_context(dir, invocation)
	if dir == nil then
		return nil
	end
	local artifact_cwd = require("neoterm.terms.artifact_cwd")
	local ctx = window.get_ctx(invocation)
	if ctx == nil then
		return
	end
	local path = vim.api.nvim_buf_get_name(ctx.bufnr)
	if path == "" or artifact_cwd.contains(path) or vim.fs.relpath(dir, path) == nil then
		return
	end
	return vim.tbl_extend("force", ctx, {
		path = vim.fs.relpath(dir, path) or path,
	})
end

---@param touch fun()
function M.create(touch)
	local artifact = {
		key = "artifact",
		display_name = "artifact",
		tag = "agent",
		restart = noop,
		start = noop,
		toggle_panel = noop,
	}
	local term = {}

	local function focus_buffer(bufnr)
		if bufnr == vim.api.nvim_get_current_buf() then
			return
		end
		local target_window = vim.fn.win_findbuf(bufnr)[1]
		if target_window then
			vim.api.nvim_set_current_win(target_window)
		else
			vim.cmd.buffer(bufnr)
		end
	end

	local function focus_artifact()
		local target = latest_artifact(project_dir())
		if target == nil then
			return
		end
		focus_buffer(target.bufnr)
		touch()
	end

	local function toggle_artifact()
		local current = vim.fs.normalize(vim.api.nvim_buf_get_name(0))
		local artifact_cwd = require("neoterm.terms.artifact_cwd")
		local from_artifact = artifact_cwd.contains(current)
		local dir = project_dir()
		if dir == nil then
			vim.notify("Project is outside projects directory", vim.log.levels.WARN)
			return
		end

		if from_artifact then
			local target = require("my.project_file").find(dir, { require("neoterm.config").dirs.artifacts })
			if target == nil then
				target = vim.fs.joinpath(dir, "README.md")
			end
			require("neoterm.config").create(vim.fn.fnameescape(target))
			touch()
			return
		end

		local target_dir = artifact_cwd.for_checkout(dir)
		local target = artifact_cwd.latest_in(target_dir)
		if target then
			focus_buffer(target.bufnr)
		else
			vim.fn.mkdir(target_dir, "p")
			require("neoterm.config").create(vim.fn.fnameescape(vim.fs.joinpath(target_dir, "index.md")))
		end
		touch()
	end

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
		local target_windows = vim.fn.win_findbuf(target.bufnr)
		local current_window = vim.api.nvim_get_current_win()
		local target_window = vim.api.nvim_win_get_buf(current_window) == target.bufnr and current_window or target_windows[1]
		local row, col
		if target_window then
			row, col = unpack(vim.api.nvim_win_get_cursor(target_window))
		else
			row, col = unpack(vim.api.nvim_buf_get_mark(target.bufnr, '"'))
		end
		row = math.max(row, 1)
		local line = vim.api.nvim_buf_get_lines(target.bufnr, row - 1, row, false)[1] or ""
		col = math.min(col, #line)
		vim.api.nvim_buf_set_text(target.bufnr, row - 1, col, row - 1, col, vim.split(str, "\n", { plain = true }))
		focus_buffer(target.bufnr)
		touch()
	end

	term.focus = function()
		focus_artifact()
	end
	term.toggle = function()
		toggle_artifact()
	end
	term.get_ctx = function(_, invocation)
		return source_context(project_dir(), invocation)
	end
	term.put = function(_, str)
		send_to_artifact(str)
	end
	artifact.term = term

	setmetatable(term, {
		__index = function()
			return function() end
		end,
	})

	return artifact
end

return M
