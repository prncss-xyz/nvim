local M = {}

function M.open_project(cwd)
	if not vim.endswith(cwd, "/") then
		cwd = cwd .. "/"
	end
	for _, file in ipairs(vim.v.oldfiles) do
		if vim.startswith(file, cwd) and vim.fn.filereadable(file) == 1 then
			vim.cmd.edit(file)
			return
		end
	end
	Snacks.picker.smart({
		cwd = cwd,
	})
end

function M.pick_project()
	Snacks.picker.pick({
		cwd = "~",
		finder = "recent_projects",
		transform = require("plugins.snacks.transform").filter_current_dir(),
		format = "file",
		confirm = { { "tcd", "open_project" } },
		patterns = { ".git", "_darcs", ".hg", ".bzr", ".svn", "package.json", "Makefile" },
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
