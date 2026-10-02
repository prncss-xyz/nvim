local M = {}

local config = require("neoterm.config")
local dirs = config.dirs
local projects = dirs.projects

local function run(command, callback)
	vim.system(
		command,
		{ text = true },
		vim.schedule_wrap(function(result)
			callback(result.code == 0, result.code == 0 and result.stdout or result.stderr or result.stdout or "")
		end)
	)
end

local function add_worktree(repo_root, worktree_path, branch, default_branch, callback)
	run({ "git", "-C", repo_root, "fetch", "origin", branch }, function()
		run({ "git", "-C", repo_root, "rev-parse", "--verify", "origin/" .. branch }, function(remote_exists)
			local function add(branch_exists)
				local command = { "git", "-C", repo_root, "worktree", "add", worktree_path }
				if not branch_exists then
					command[#command + 1] = "-b"
					command[#command + 1] = branch
					command[#command + 1] = default_branch
				else
					command[#command + 1] = branch
				end
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

	local repo_dir = vim.fs.joinpath(projects, parts[1])
	local repo_root
	for _, branch in ipairs(config.default_branches) do
		local candidate = vim.fs.joinpath(repo_dir, branch)
		if vim.uv.fs_stat(candidate) then
			repo_root = candidate
			break
		end
	end
	if not repo_root then
		return callback(true)
	end

	add_worktree(repo_root, dir, parts[2], vim.fs.basename(repo_root), callback)
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
		config.create(vim.fn.fnameescape(target))
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

	local default_branch
	for _, candidate in ipairs(config.default_branches) do
		if vim.uv.fs_stat(parent .. "/" .. candidate) then
			default_branch = candidate
			break
		end
	end
	if not default_branch then
		vim.notify("Default branch worktree not found in " .. parent, vim.log.levels.ERROR)
		return
	end

	add_worktree(toplevel, worktree_path, branch, default_branch, function(ok)
		if ok then
			on_success(get_default_file(worktree_path, rel_path), worktree_path)
		end
	end)
end

--- Remove the wohktree containing the current buffer, after confirmation.
--- Tracked changes and untracked files are protected by git worktree remove.
function M.remove_current_worktree(on_success, skip_confirmation)
	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		vim.notify("No file open", vim.log.levels.WARN)
		return
	end

	run({ "git", "-C", vim.fs.dirname(current_file), "rev-parse", "--show-toplevel" }, function(ok, output)
		if not ok then
			vim.notify("Current file is not in a git worktree", vim.log.levels.ERROR)
			return
		end
		local worktree_path = vim.fs.normalize(vim.trim(output))
		local function remove(confirmed)
			if not confirmed then
				return
			end
			require("neoterm.terms").kill_in_dir(worktree_path)
			for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
				local path = vim.api.nvim_buf_get_name(bufnr)
				if path ~= "" and vim.startswith(vim.fs.normalize(path), worktree_path .. "/") then
					config.bdelete(bufnr)
				end
			end
			run({ "git", "-C", worktree_path, "worktree", "remove", worktree_path }, function(removed, result)
				if not removed then
					vim.notify("Failed to remove worktree: " .. result, vim.log.levels.ERROR)
					return
				end
				if on_success then
					on_success(worktree_path)
				end
			end)
		end
		if skip_confirmation then
			remove(true)
		else
			require("neoterm.helpers.confirm")("Remove worktree " .. worktree_path .. "?", remove)
		end
	end)
end

function M.merge_to_default()
	local current_file = vim.fn.expand("%:p")
	if current_file == "" then
		vim.notify("No file open", vim.log.levels.WARN)
		return
	end

	run({ "git", "-C", vim.fs.dirname(current_file), "rev-parse", "--show-toplevel" }, function(ok, output)
		if not ok then
			vim.notify("Current file is not in a git worktree", vim.log.levels.ERROR)
			return
		end
		local worktree_path = vim.fs.normalize(vim.trim(output))
		local branch = vim.trim(vim.fn.system({ "git", "-C", worktree_path, "branch", "--show-current" }))
		if vim.v.shell_error ~= 0 or branch == "" or vim.tbl_contains(config.default_branches, branch) then
			vim.notify("Current worktree must be on a non-default branch", vim.log.levels.ERROR)
			return
		end
		local default_path
		for _, candidate in ipairs(config.default_branches) do
			local path = vim.fs.joinpath(vim.fs.dirname(worktree_path), candidate)
			if vim.uv.fs_stat(path) then
				default_path = path
				break
			end
		end
		if not default_path then
			vim.notify("Default branch worktree not found", vim.log.levels.ERROR)
			return
		end
		local target = vim.fs.basename(default_path)
		require("neoterm.helpers.confirm")("Merge " .. branch .. " into " .. target .. "?", function(confirmed)
			if not confirmed then
				return
			end
			local function check_clean(path, callback)
				run({ "git", "-C", path, "status", "--porcelain" }, function(clean, status)
					if not clean or status ~= "" then
						vim.notify("Worktree must be clean before merging: " .. path, vim.log.levels.ERROR)
						return
					end
					callback()
				end)
			end
			check_clean(worktree_path, function()
				check_clean(default_path, function()
					run({ "git", "-C", worktree_path, "rebase", target }, function(rebased, result)
						if not rebased then
							vim.notify("Rebase failed; resolve conflicts before merging: " .. result, vim.log.levels.ERROR)
							return
						end
						run({ "git", "-C", worktree_path, "rev-list", "--count", target .. "..HEAD" }, function(counted, count_output)
							if not counted then
								vim.notify("Failed to count branch commits: " .. count_output, vim.log.levels.ERROR)
								return
							end
							local count = tonumber(vim.trim(count_output))
							assert(count)
							local function fast_forward()
								run({ "git", "-C", default_path, "merge", "--ff-only", branch }, function(merged, merge_result)
									if not merged then
										vim.notify("Failed to fast-forward default branch: " .. merge_result, vim.log.levels.ERROR)
										return
									end
									M.remove_current_worktree(nil, true)
								end)
							end
							if count <= 1 then
								fast_forward()
								return
							end
							run({ "git", "-C", worktree_path, "rev-parse", "HEAD" }, function(saved, original_head)
								if not saved then
									vim.notify("Failed to save branch tip: " .. original_head, vim.log.levels.ERROR)
									return
								end
								local original = vim.trim(original_head)
								run({ "git", "-C", worktree_path, "reset", "--soft", target }, function(reset, reset_result)
									if not reset then
										vim.notify("Failed to prepare squash: " .. reset_result, vim.log.levels.ERROR)
										return
									end
									run({ "git", "-C", worktree_path, "commit", "-m", "Merge " .. branch }, function(committed, commit_result)
										if not committed then
											run({ "git", "-C", worktree_path, "reset", "--hard", original }, function(restored, restore_result)
												vim.notify("Failed to commit squash: " .. commit_result .. (restored and "" or "; restoration failed: " .. restore_result), vim.log.levels.ERROR)
											end)
											return
										end
										fast_forward()
									end)
								end)
							end)
						end)
					end)
				end)
			end)
		end)
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
