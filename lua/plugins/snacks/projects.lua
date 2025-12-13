local M = {}

local is_file_cur_win = require("my.windows").is_file_cur_win

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

function M.pick_project()
	Snacks.picker.pick({
		finder = function(opts, ctx)
			return require("snacks.picker.source.proc").proc(
				ctx:opts({
					cwd = vim.env.HOME .. "/Projects",
					-- fd '\.git$' -a --prune -u -t d -x echo {//}
					cmd =  "fd" ,
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
