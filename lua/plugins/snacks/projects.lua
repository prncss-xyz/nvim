local M = {}

local note_dir = require("my.parameters").dirs.notes

local is_file_cur_win = require("my.windows").is_file_cur_win
local find_project_file = require("my.project_file").find

function M.toggle_project()
	if is_file_cur_win() then
		M.open_project(vim.env.HOME, { vim.fn.getcwd() }, M.pick_project)
	end
end

function M.toggle_file()
	if is_file_cur_win() then
		M.open_project(vim.fn.getcwd(), { vim.api.nvim_buf_get_name(0) })
	end
end

function M.toggle_cursor()
	local bufnr = vim.api.nvim_win_get_buf(0)
	local jumplist, len = unpack(vim.fn.getjumplist())
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	for i = len, 1, -1 do
		if bufnr == jumplist[i].bufnr then
			local jrow = jumplist[i].lnum
			local jcol = jumplist[i].col
			if row ~= jrow and col ~= jcol then
				vim.api.nvim_win_set_cursor(0, { jrow, jcol })
				return
			end
		end
	end
end

function M.open_project(cwd, exclude, fallback)
	cwd = vim.fs.normalize(cwd)
	local path = find_project_file(cwd, exclude)
	if path then
		vim.cmd.edit(vim.fn.fnameescape(path))
	elseif fallback then
		fallback(cwd)
	else
		Snacks.picker.smart({
			cwd = cwd,
			transform = require("plugins.snacks.transform").exclude_current(),
		})
	end
end

local filetype_to_lang = {
	javascript = "typescript",
	javascriptreact = "typescript",
	typescript = "typescript",
	typescriptreact = "typescript",
}

function M.pick_current_lang_note()
	return M.pick_note_with("/dev/lang/" .. (filetype_to_lang[vim.bo.filetype] or vim.bo.filetype))
end

function M.pick_note_with(stem)
	local dirname = note_dir .. stem
	vim.fn.mkdir(dirname, "p")
	Snacks.picker.files({
		cwd = dirname,
		matcher = {
			frecency = true,
		},
		on_show = function(picker)
			if #picker:items() == 0 then
				picker:close()
				vim.cmd.edit(dirname .. "/index.md")
			end
		end,
		args = { "-e", "md" },
	})
end

local pick_config = {
	format = require("plugins.snacks.format").directory_with_parent,
	confirm = { { "tcd", "open_project" } },
	recent = true,
	matcher = {
		frecency = true,
		sort_empty = true,
		cwd_bonus = false,
	},
	sort = { fields = { "score:desc", "idx" } },
	win = {
		preview = { minimal = true },
		input = {
			keys = {
				-- every action will always first change the cwd of the current tabpage to the project
				["<c-e>"] = { { "tcd", "picker_explorer" }, mode = { "n", "i" } },
				["<c-f>"] = { { "tcd", "picker_files" }, mode = { "n", "i" } },
				["<c-g>"] = { { "tcd", "picker_grep" }, mode = { "n", "i" } },
				["<c-r>"] = { { "tcd", "picker_recent" }, mode = { "n", "i" } },
				["<c-w>"] = { { "tcd" }, mode = { "n", "i" } },
				["<c-t>"] = {
					function(picker)
						vim.cmd("tabnew")
						Snacks.notify("New tab opened")
						picker:close()
						Snacks.picker.projects()
					end,
					mode = { "n", "i" },
				},
			},
		},
	},
}

function M.pick_worktree()
	Snacks.picker.pick(vim.tbl_extend("force", pick_config, {
		finder = function(opts, ctx)
			-- toplevel of the worktree containing cwd; works from any subdirectory
			local current = vim.fs.normalize(vim.trim(vim.fn.system("git rev-parse --show-toplevel")))
			return require("snacks.picker.source.proc").proc(
				ctx:opts({
					cwd = vim.fn.getcwd(),
					cmd = "git",
					args = { "worktree", "list" },
					transform = function(item)
						-- "git worktree list" output: "<path> <sha> [<branch>]" (or "(detached HEAD)")
						-- keep just the path (first run of non-whitespace)
						local path = item.text:match("^(%S+)")
						if path then
							path = vim.fs.normalize(path)
						end
						if not path or path == current then
							return false
						end
						item.text = path
						item.file = path
						item.dir = true
					end,
				}),
				ctx
			)
		end,
	}))
end

function M.pick_project()
	Snacks.picker.pick(vim.tbl_extend("force", pick_config, {
		finder = function(opts, ctx)
			return require("snacks.picker.source.proc").proc(
				ctx:opts({
					cwd = require("my.parameters").dirs.projects,
					cmd = "fd",
					args = { "\\.git$", "-a", "--prune", "-u", "-d", "3", "-x", "echo", "{//}" },
					transform = function(item)
						item.file = item.text
						item.dir = true
					end,
				}),
				ctx
			)
		end,
	}))
end

return M
