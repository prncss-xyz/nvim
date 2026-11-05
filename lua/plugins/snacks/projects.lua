local M = {}

local note_dir = require("my.parameters").dirs.notes

function M.toggle_project()
	if vim.bo[0].buftype == "" then
		M.open_project(vim.env.HOME, { vim.fn.getcwd() }, require("neoterm.pickers.projects").pick_project)
	end
end

function M.toggle_file()
	if vim.bo[0].buftype == "" then
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
	local path = require("neoterm.helpers.project_file").get_project_file(cwd, exclude)
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

return M
