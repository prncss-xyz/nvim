local M = {}

local function directory_with_parent(item, picker)
	local ret = {} ---@type snacks.picker.Highlight[]

	if not item.file then
		return ret
	end

	local path = Snacks.picker.util.path(item) or item.file

	if picker.opts.icons.files.enabled ~= false then
		local name, cat = path, (item.dir and "directory" or "file")
		local icon, hl = Snacks.util.icon(name, cat, {
			fallback = picker.opts.icons.files,
		})
		if item.dir and item.open then
			icon = picker.opts.icons.files.dir_open
		end
		icon = Snacks.picker.util.align(icon, picker.opts.formatters.file.icon_width or 2)
		ret[#ret + 1] = { icon, hl, virtual = true }
	end

	local base_hl = item.dir and "SnacksPickerDirectory" or "SnacksPickerFile"
	local dir_hl = "SnacksPickerDir"

	local projects_dir = require("neoterm.config").dirs.projects
	local projects_dir_normalized = projects_dir:gsub("/$", "") .. "/"

	local clean_path = path:gsub("/$", "")

	local relative_path
	if clean_path:sub(1, #projects_dir_normalized) == projects_dir_normalized then
		relative_path = clean_path:sub(#projects_dir_normalized + 1)
	else
		relative_path = clean_path
	end

	if relative_path == "" then
		ret[#ret + 1] = { ".", base_hl, field = "file" }
	else
		local dir, base = relative_path:match("^(.*)/(.+)$")
		if base and dir then
			if item.branch and item.branch == base then
				ret[#ret + 1] = { dir, base_hl, field = "file" }
			else
				ret[#ret + 1] = { dir .. "/", dir_hl, field = "file" }
				ret[#ret + 1] = { base, base_hl, field = "file" }
			end
		else
			ret[#ret + 1] = { relative_path, base_hl, field = "file" }
		end
	end

	ret[#ret + 1] = { " " }
	return ret
end

local pick_config = {
	format = directory_with_parent,
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
						M.pick_project()
					end,
					mode = { "n", "i" },
				},
			},
		},
	},
}

local function project_items(index, worktrees)
	local current
	if worktrees then
		local cwd = vim.fs.normalize(vim.fn.getcwd())
		for _, checkout in ipairs(index.checkouts) do
			if cwd == checkout.path or vim.startswith(cwd, checkout.path .. "/") then
				if not current or #checkout.path > #current.path then
					current = checkout
				end
			end
		end
		if not current then
			return {}
		end
	end
	local items = {}
	for _, checkout in ipairs(index.checkouts) do
		if not worktrees or (checkout.git_dir == current.git_dir and checkout.path ~= current.path) then
			table.insert(items, { text = checkout.path, file = checkout.path, dir = true })
		end
	end
	return items
end

local function pick_projects(worktrees)
	Snacks.picker.pick(vim.tbl_extend("force", pick_config, {
		finder = function(_, ctx)
			local tasks = require("neoterm.terms.artifacts.tasks")
			local index = tasks.projects()
			if index then
				return project_items(index, worktrees)
			end
			return function(cb)
				local unsubscribe = tasks.subscribe(function()
					ctx.async:resume()
				end)
				ctx.async:on("done", unsubscribe)
				index = tasks.projects()
				while not index do
					ctx.async:suspend()
					index = tasks.projects()
				end
				unsubscribe()
				for _, item in ipairs(project_items(index, worktrees)) do
					cb(item)
				end
			end
		end,
	}))
end

function M.pick_worktree()
	pick_projects(true)
end

function M.pick_project()
	pick_projects(false)
end

return M
