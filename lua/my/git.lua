local M = {}

local dirs = require("my.parameters").dirs
local projects = dirs.projects
local artifacts = dirs.artifacts

local function path_exists(path)
	local ok, stat = pcall(vim.uv.fs_lstat, path)
	return ok and stat ~= nil
end

local function relative_path(from, to)
	local from_parts = vim.split(vim.fs.normalize(from), "/", { plain = true, trimempty = true })
	local to_parts = vim.split(vim.fs.normalize(to), "/", { plain = true, trimempty = true })
	local common_count = 0

	while from_parts[common_count + 1] ~= nil and from_parts[common_count + 1] == to_parts[common_count + 1] do
		common_count = common_count + 1
	end

	local parts = {}
	for _ = common_count + 1, #from_parts do
		parts[#parts + 1] = ".."
	end
	for index = common_count + 1, #to_parts do
		parts[#parts + 1] = to_parts[index]
	end

	return #parts == 0 and "." or table.concat(parts, "/")
end

local function get_repo_name(repo_root)
	local remote = vim.trim(vim.fn.system({ "git", "-C", repo_root, "config", "--get", "remote.origin.url" }))
	if vim.v.shell_error == 0 and remote ~= "" then
		local repo = remote:gsub("/$", ""):gsub("%.git$", ""):match("([^/:]+)$")
		if repo ~= nil then
			return repo
		end
	end

	return vim.fs.basename(repo_root)
end

local function get_branch_name(repo_root)
	local branch = vim.trim(vim.fn.system({ "git", "-C", repo_root, "branch", "--show-current" }))
	if vim.v.shell_error == 0 and branch ~= "" then
		return branch
	end

	return "main"
end

local function link_artifacts(repo_root, repo, branch)
	local target = artifacts .. "/" .. repo .. "/" .. branch
	local link_path = repo_root .. "/.artifacts"

	local ok, result = pcall(vim.fn.mkdir, target, "p")
	if not ok or (result == 0 and vim.fn.isdirectory(target) == 0) then
		vim.notify("Failed to create artifacts directory: " .. target, vim.log.levels.WARN)
		return
	end

	if path_exists(link_path) then
		return
	end

	local link_target = relative_path(repo_root, target)
	local ok_link, linked, error_message = pcall(vim.uv.fs_symlink, link_target, link_path)
	if not ok_link or not linked then
		vim.notify(
			"Failed to create artifacts link: " .. tostring(ok_link and error_message or linked),
			vim.log.levels.WARN
		)
	end
end

--- Get the best file to open in a git repository.
--- Priority: preferred relative path → README.md → first git-tracked file → README.md (fallback)
--- @param repo_dir string  Root directory of the repository
--- @param preferred_rel string|nil  Optional preferred relative path inside the repo
--- @return string  Resolved file path (may not exist yet)
local function get_default_file(repo_dir, preferred_rel)
	if preferred_rel ~= nil then
		local target = repo_dir .. "/" .. preferred_rel
		if vim.fn.filereadable(target) == 1 then
			return target
		end
	end

	local target = repo_dir .. "/README.md"
	if vim.fn.filereadable(target) == 1 then
		return target
	end

	local ls_output = vim.fn.system({ "git", "-C", repo_dir, "ls-files" })
	local first = ls_output:match("[^\n]+")
	if first then
		return repo_dir .. "/" .. first
	end

	return repo_dir .. "/README.md"
end

function M.clone_github()
	vim.ui.input({ prompt = "Github repo (user/repo or repo): " }, function(input)
		if not input or input == "" then
			return
		end

		local repo_dir = projects .. "/" .. input
		vim.fn.mkdir(repo_dir, "p")

		-- check if upstream exists on github
		local gh_out = vim.trim(
			vim.fn.system({ "gh", "repo", "view", input, "--json", "defaultBranchRef", "-q", ".defaultBranchRef.name" })
		)
		local has_upstream = vim.v.shell_error == 0

		if has_upstream then
			local branch = gh_out
			local clone_dir = repo_dir .. "/" .. branch
			if vim.fn.isdirectory(clone_dir) == 0 then
				local result = vim.fn.system({ "gh", "repo", "clone", input, clone_dir })
				if vim.v.shell_error ~= 0 then
					vim.notify("Failed to clone: " .. result, vim.log.levels.ERROR)
					return
				end
			end
			repo_dir = clone_dir
		elseif not input:find("/") then
			-- no upstream and bare repo name: create a new public repo
			local result = vim.fn.system(
				"cd "
					.. vim.fn.shellescape(projects)
					.. " && gh repo create "
					.. vim.fn.shellescape(input)
					.. " --public --clone"
			)
			if vim.v.shell_error ~= 0 then
				vim.notify("Failed to create repo: " .. result, vim.log.levels.ERROR)
				return
			end
			-- gh clones into projects/repo_name; move into repo_dir if needed
			local repo_basename = input:match("[^/]+$")
			local cwd_clone = projects .. "/" .. repo_basename
			if cwd_clone ~= repo_dir and vim.fn.isdirectory(cwd_clone) == 1 then
				vim.fn.rename(cwd_clone, repo_dir)
			end
		else
			vim.notify("Upstream not found for " .. input, vim.log.levels.ERROR)
			return
		end

		link_artifacts(repo_dir, get_repo_name(repo_dir), get_branch_name(repo_dir))

		local target = get_default_file(repo_dir)
		require("my.create").create(vim.fn.fnameescape(target))
	end)
end

function M.create_worktree(branch, on_success)
	local toplevel = vim.trim(vim.fn.system("git rev-parse --show-toplevel"))
	if vim.v.shell_error ~= 0 then
		vim.notify("Not in a git repository", vim.log.levels.ERROR)
		return
	end
	toplevel = vim.fs.normalize(toplevel)

	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		vim.notify("No file open", vim.log.levels.WARN)
		return
	end
	current_file = vim.fs.normalize(current_file)

	local rel_path = current_file:sub(#toplevel + 2)

	local parent = vim.fs.dirname(toplevel)
	local worktree_path = parent .. "/" .. branch

	-- fetch so we know what exists at origin
	vim.fn.system({ "git", "fetch", "origin", branch })

	vim.fn.system({ "git", "rev-parse", "--verify", "origin/" .. branch })
	local use_remote = vim.v.shell_error == 0

	local cmd = { "git", "worktree", "add", worktree_path }
	if use_remote then
		cmd[#cmd + 1] = branch
	else
		cmd[#cmd + 1] = "-b"
		cmd[#cmd + 1] = branch
	end

	local result = vim.fn.system(cmd)

	if vim.v.shell_error ~= 0 then
		vim.notify("Failed to create worktree: " .. result, vim.log.levels.ERROR)
		return
	end

	link_artifacts(worktree_path, get_repo_name(worktree_path), branch)
	on_success(get_default_file(worktree_path, rel_path))
end

function M.create_worktree_from_input(cb)
	vim.ui.input({ prompt = "Branch name: " }, function(branch)
		if not branch or branch == "" then
			return
		end
		M.create_worktree(branch, cb)
	end)
end

return M
