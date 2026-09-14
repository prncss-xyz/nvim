local M = {}

local artifact_cwd = require("plugins.toggleterm.terms.artifact_cwd")
local config = require("plugins.toggleterm.config")

local function sanitize_branch(summary)
	local branch = summary:lower():gsub("[^%w._-]", "-")
	return branch:gsub("^-+", ""):gsub("-+$", "")
end

local function existing_branches(callback)
	vim.system({ "git", "branch", "-a" }, { text = true }, function(result)
		if result.code ~= 0 then
			callback({})
			return
		end

		local seen = {}
		for line in result.stdout:gmatch("[^\n]+") do
			local name = line:sub(3) -- strip leading 2-char marker ('* ', '  ')
			name = name:gsub("^remotes/[^/]+/", "") -- strip remotes/<remote>/
			if name ~= "" and not name:match(" -> ") then
				seen[name] = true
			end
		end
		callback(seen)
	end)
end

local function find_free_branch(branch, seen)
	if not seen[branch] then
		return branch
	end
	for n = 0, 999 do
		local candidate = string.format("%s-%03d", branch, n)
		if not seen[candidate] then
			return candidate
		end
	end
	return branch
end

local function branch_name(input, callback, root)
	root = root or vim.fs.root(0, ".git") or vim.uv.cwd()
	vim.notify("Naming branch...", vim.log.levels.INFO)
	local command = vim.split(config.ai_query, "%s+", { trimempty = true })
	local prompt = config.create_task_name:gsub("{input}", function()
		return input
	end)
	vim.system(command, { cwd = root, text = true, stdin = prompt }, function(result)
		vim.schedule(function()
			assert(result.code == 0, result.stderr)
			local branch = sanitize_branch(result.stdout)
			assert(branch ~= "", "create-branch-name returned an empty name")
			existing_branches(vim.schedule_wrap(function(seen)
				callback(find_free_branch(branch, seen), root)
			end))
		end)
	end)
end

function M.create_artifact(input, filename, root, directory)
	local artifacts = require("my.parameters").dirs.artifacts

	local function create(target, project_root)
		branch_name(input, function(branch)
			local path = vim.fs.joinpath(target, branch .. "." .. filename)
			vim.fn.writefile(vim.split(input, "\n", { plain = true }), path)
			vim.notify("Created " .. assert(vim.fs.relpath(artifacts, path)), vim.log.levels.INFO)
		end, project_root)
	end

	if directory then
		create(directory, root or assert(artifact_cwd.resolve(directory), "Artifact project not found"))
		return
	end

	local directories = {}
	local seen = {}
	local function add_directory(path)
		if not seen[path] then
			seen[path] = true
			table.insert(directories, path)
		end
	end

	local project_directory = artifact_cwd.for_project(root)
	local branch_directory = artifact_cwd.for_checkout(root)
	if branch_directory ~= project_directory then
		add_directory(branch_directory)
	end
	add_directory(project_directory)

	local existing_directories = {}
	for name, kind in vim.fs.dir(artifacts, { depth = math.huge }) do
		local path = vim.fs.joinpath(artifacts, name)
		if kind == "directory" and artifact_cwd.resolve(path) then
			table.insert(existing_directories, path)
		end
	end
	table.sort(existing_directories)
	for _, path in ipairs(existing_directories) do
		add_directory(path)
	end
	vim.ui.select(directories, {
		prompt = "Select artifact directory",
		format_item = function(path)
			return assert(vim.fs.relpath(artifacts, path))
		end,
	}, function(selected)
		if selected then
			vim.fn.mkdir(selected, "p")
			create(selected, root)
		end
	end)
end

function M.artifact_to_worktree(branch, opts)
	vim.notify("Creating worktree " .. branch .. "...", vim.log.levels.INFO)
	require("plugins.toggleterm.terms.git").create_worktree(branch, function(_, worktree_path)
		opts.dir = worktree_path
		require("plugins.toggleterm.terms").focus(opts)
	end)
end

function M.input_to_worktree(input, prompt, opts)
	branch_name(input, function(branch)
		opts.cmd = opts.cmd .. prompt
		M.artifact_to_worktree(branch, opts)
	end)
end

local function pi_prompt(command)
	return function(file, dir)
		return {
			key = "pi",
			dir = dir,
			cmd = string.format("p /%s @%q", command, file),
		}
	end
end

local prompts = {
	plan = pi_prompt("implement"),
}

local function with_worktree(path)
	local project_dir = artifact_cwd.resolve(path)
	local artifact_root = project_dir and artifact_cwd.for_project(project_dir) or nil
	local relative_path = artifact_root and vim.fs.relpath(artifact_root, path) or nil
	if not relative_path then
		vim.notify("Current buffer is not inside the project's artifacts", vim.log.levels.ERROR)
		return
	end

	local branch, task = relative_path:match("^([^/]+)/([^/]+)%.md$")
	if not branch or not task then
		vim.notify("Artifact filename must match {artifacts}/{branch}/{task}.md", vim.log.levels.ERROR)
		return
	end
	local prompt = prompts[task]
	if not prompt then
		vim.notify("This task is not configured")
		return
	end

	local current_branch = vim.trim(vim.fn.system({ "git", "-C", project_dir, "branch", "--show-current" }))
	assert(vim.v.shell_error == 0 and current_branch ~= "", "Failed to determine current Git branch")

	local terms = require("plugins.toggleterm.terms")
	if branch == current_branch then
		terms.focus(prompt(path, project_dir))
		return
	end

	vim.notify("Creating worktree " .. branch .. "...", vim.log.levels.INFO)
	require("plugins.toggleterm.terms.git").create_worktree(branch, function(_, worktree_path)
		terms.focus(prompt(path, worktree_path))
	end)
end

function M.with_worktree()
	with_worktree(vim.api.nvim_buf_get_name(0))
end

function M.pick_with_worktree(include_dirty)
	local dirs = require("my.parameters").dirs
	local files = vim.fs.find(function(name, path)
		if not name:match("%.md$") then
			return false
		end
		local relative = vim.fs.relpath(dirs.artifacts, vim.fs.joinpath(path, name))
		if relative == nil then
			return false
		end
		local project, branch, task = relative:match("^([^/]+)/([^/]+)/([^/]+)%.md$")
		if task == nil or prompts[task] == nil then
			return false
		end
		return include_dirty or vim.fn.isdirectory(vim.fs.joinpath(dirs.projects, project, branch)) == 0
	end, { path = dirs.artifacts, type = "file", limit = math.huge })
	table.sort(files)

	vim.ui.select(files, {
		prompt = "Artifact Worktree",
		format_item = function(path)
			return assert(vim.fs.relpath(dirs.artifacts, path))
		end,
	}, function(path)
		if path then
			with_worktree(path)
		end
	end)
end

return M
