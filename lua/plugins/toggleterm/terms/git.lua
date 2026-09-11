local M = {}

local dirs = require("my.parameters").dirs
local projects = dirs.projects

local function run(command, callback)
	vim.system(
		command,
		{ text = true },
		vim.schedule_wrap(function(result)
			callback(result.code == 0, result.stdout or result.stderr or "")
		end)
	)
end

local function add_worktree(repo_root, worktree_path, branch, callback)
	run({ "git", "-C", repo_root, "fetch", "origin", branch }, function()
		run({ "git", "-C", repo_root, "rev-parse", "--verify", "origin/" .. branch }, function(remote_exists)
			local function add(branch_exists)
				local command = { "git", "-C", repo_root, "worktree", "add", worktree_path }
				if not branch_exists then
					command[#command + 1] = "-b"
				end
				command[#command + 1] = branch
				run(command, function(ok, output)
					if not ok then
						vim.notify("Failed to create worktree: " .. output, vim.log.levels.ERROR)
					end
					callback(ok)
				end)
			end

			if remote_exists then
				return add(true)
			end
			run({ "git", "-C", repo_root, "rev-parse", "--verify", branch }, function(local_exists)
				add(local_exists)
			end)
		end)
	end)
end

--- Create a missing <projects>/<repo>/<branch> worktree before using it.
--- Other paths are left alone.
function M.ensure_worktree(dir, callback)
	if vim.uv.fs_stat(dir) then
		return callback(true)
	end

	local relative = vim.fs.relpath(projects, vim.fs.abspath(dir))
	local parts = relative and vim.split(relative, "/", { plain = true, trimempty = true }) or {}
	if #parts ~= 2 then
		return callback(true)
	end

	local repo_root = vim.fs.joinpath(projects, parts[1], "main")
	if not vim.uv.fs_stat(repo_root) then
		return callback(true)
	end

	add_worktree(repo_root, dir, parts[2], callback)
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

	if vim.fn.isdirectory(worktree_path) == 1 then
		local existing_toplevel =
			vim.trim(vim.fn.system({ "git", "-C", worktree_path, "rev-parse", "--show-toplevel" }))
		if vim.v.shell_error ~= 0 or vim.fs.normalize(existing_toplevel) ~= worktree_path then
			vim.notify("Expected worktree path is occupied: " .. worktree_path, vim.log.levels.ERROR)
			return
		end

		local existing_branch = vim.trim(vim.fn.system({ "git", "-C", worktree_path, "branch", "--show-current" }))
		if vim.v.shell_error ~= 0 or existing_branch ~= branch then
			vim.notify(
				string.format("Expected %s to be on branch %s, found %s", worktree_path, branch, existing_branch),
				vim.log.levels.ERROR
			)
			return
		end

		on_success(get_default_file(worktree_path, rel_path), worktree_path)
		return
	end

	add_worktree(toplevel, worktree_path, branch, function(ok)
		if ok then
			on_success(get_default_file(worktree_path, rel_path), worktree_path)
		end
	end)
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
