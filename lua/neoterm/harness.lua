local M = {}

local artifact_cwd = require("neoterm.terms.artifacts.cwd")
local config = require("neoterm.config")
local paths = require("neoterm.terms.artifacts.paths")
local last_created_artifact

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
	local command = vim.split(config.llm_query, "%s+", { trimempty = true })
	local prompt = config.tasks.create_task_name:gsub("{input}", function()
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

function M.select_artifact_directory(root, callback)
	local artifacts = config.dirs.artifacts
	local directories = {}
	local seen = {}
	local function add_directory(path)
		if not seen[path] then
			seen[path] = true
			table.insert(directories, path)
		end
	end

	local project_directory = artifact_cwd.for_project(root)
	for _, branch_directory in ipairs(artifact_cwd.artifact_folders(root)) do
		if branch_directory ~= project_directory then
			add_directory(branch_directory)
		end
	end
	add_directory(project_directory)

	local existing_directories = {}
	local resolve_checkouts = paths.checkout_resolver()
	for name, kind in vim.fs.dir(artifacts, { depth = math.huge }) do
		local path = vim.fs.joinpath(artifacts, name)
		if kind == "directory" and #resolve_checkouts(path) > 0 then
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
			callback(selected)
		end
	end)
end

function M.create_artifact(input, filename, root, directory)
	local artifacts = config.dirs.artifacts

	local function create(target, project_root)
		branch_name(input, function(branch)
			local directory = vim.fs.joinpath(target, branch)
			vim.fn.mkdir(directory, "p")
			local path = vim.fs.joinpath(directory, filename)
			vim.fn.writefile(vim.split(input, "\n", { plain = true }), path)
			last_created_artifact = path
			vim.notify("Created " .. assert(vim.fs.relpath(artifacts, path)), vim.log.levels.INFO)
		end, project_root)
	end

	if directory then
		create(
			directory,
			root
				or artifact_cwd.resolve(directory)
				or assert(
					paths.default_checkout(paths.source(vim.fs.joinpath(directory, filename)).project),
					"Artifact project not found"
				)
		)
		return
	end

	M.select_artifact_directory(root, function(selected)
		create(selected, root)
	end)
end

function M.focus_last_created_artifact()
	if not last_created_artifact then
		vim.notify("No artifact has been created in this session", vim.log.levels.WARN)
		return
	end
	config.create(vim.fn.fnameescape(last_created_artifact))
end

function M.artifact_to_worktree(branch, opts)
	vim.notify("Creating worktree " .. branch .. "...", vim.log.levels.INFO)
	require("neoterm.git").create_worktree(branch, function(_, worktree_path)
		opts.cwd = worktree_path
		require("neoterm.terms").focus(opts)
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
			cwd = dir,
			cmd = string.format("p /%s @%q", command, file),
		}
	end
end

local prompts = {
	plan = pi_prompt("implement"),
}

local function artifact_branch_task(path)
	if vim.fs.relpath(config.dirs.artifacts, vim.fs.abspath(path)) == nil then
		return nil
	end
	local identity = paths.source(path)
	local task = identity.source:match("^(.*)%.md$")
	if not prompts[task] then
		return nil
	end
	return identity, task
end

local function with_worktree(path)
	local identity, task = artifact_branch_task(path)
	if not identity then
		vim.notify("Artifact filename must identify a configured task", vim.log.levels.ERROR)
		return
	end
	local checkout = paths.checkout(identity.project, paths.branch(identity))
	require("neoterm.git").ensure_worktree(checkout, function(ok)
		if ok then
			paths.link(checkout, identity.folder, identity.file)
			local command = prompts[task](path, checkout)
			command.artifact_dir = identity.folder
			command.artifact_source = identity.file
			require("neoterm.terms").focus(command)
		end
	end)
end

function M.with_worktree()
	with_worktree(vim.api.nvim_buf_get_name(0))
end

-- TODO: bind
function M.pick_with_worktree(include_dirty)
	local dirs = config.dirs
	local files = vim.fs.find(function(name, path)
		if not name:match("%.md$") then
			return false
		end
		local relative = vim.fs.relpath(dirs.artifacts, vim.fs.joinpath(path, name))
		if relative == nil then
			return false
		end
		local identity = artifact_branch_task(vim.fs.joinpath(path, name))
		if identity == nil then
			return false
		end
		return include_dirty or vim.fn.isdirectory(paths.checkout(identity.project, identity.branch)) == 0
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
