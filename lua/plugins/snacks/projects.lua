local M = {}

local notes = require("my.parameters").dirs.notes

local is_file_cur_win = require("my.windows").is_file_cur_win

function M.is_binary_by_ext(filepath)
	if not filepath then
		return false
	end

	-- Extract the extension (handles cases like .tar.gz by taking the last part)
	local ext = filepath:match("^.+(%..+)$")
	if not ext then
		return false
	end
	ext = ext:lower()

	-- Define binary extensions
	local binary_extensions = {
		[".bin"] = true,
		[".exe"] = true,
		[".dll"] = true,
		[".so"] = true,
		[".o"] = true,
		[".pyc"] = true,
		[".pyd"] = true,
		[".node"] = true,
		[".png"] = true,
		[".jpg"] = true,
		[".jpeg"] = true,
		[".gif"] = true,
		[".pdf"] = true,
		[".zip"] = true,
		[".tar"] = true,
		[".gz"] = true,
		[".7z"] = true,
		[".wasm"] = true,
		[".sqlite"] = true,
		[".db"] = true,
	}

	return binary_extensions[ext] or false
end

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

local function get_test(cwd, exclude)
	return function(fname)
		if fname == "" then
			return false
		end
		if exclude then
			for _, ex in pairs(exclude) do
				if vim.startswith(fname, ex) then
					return false
				end
			end
		end
		return vim.startswith(fname, cwd) and vim.fn.filereadable(fname) == 1
	end
end

-- FIXME:
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
	if not vim.endswith(cwd, "/") then
		cwd = cwd .. "/"
	end
	local test = get_test(cwd, exclude)
	local jumplist, len = unpack(vim.fn.getjumplist())
	local done = {}
	for i = len, 1, -1 do
		local bufnr = jumplist[i].bufnr
		if not done[bufnr] then
			done[bufnr] = true
			local fname = vim.api.nvim_buf_get_name(bufnr)
			if test(fname) then
				vim.cmd.edit(fname)
				return
			end
		end
	end
	if fallback then
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

function M.pick_current_project_note()
	return M.pick_note_with("/dev/projects/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t"))
end

function M.pick_note_with(stem)
	local dirname = notes .. stem
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

function M.pick_project()
            print(require("my.parameters").dirs.projects)

	Snacks.picker.pick({
		finder = function(opts, ctx)
			return require("snacks.picker.source.proc").proc(
				ctx:opts({
					cwd = require("my.parameters").dirs.projects,
					-- fd '\.git$' -a --prune -u -t d -x echo {//}
					cmd = "fd",
					args = { "\\.git$", "-a", "--prune", "-u", "-t", "d", "-x", "echo", "{//}" },
					transform = function(item)
						item.file = item.text
						item.dir = true
					end,
				}),
				ctx
			)
		end,
		format = "file",
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
	})
end

return M
