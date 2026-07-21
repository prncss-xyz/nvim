local M = {}

local projects = require("my.parameters").dirs.projects

-- TODO: use khutulun

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

		-- open a file: README.md, first git-tracked file, or create empty README.md
		local target = repo_dir .. "/README.md"
		if vim.fn.filereadable(target) ~= 1 then
			local ls = vim.fn.system({ "git", "-C", repo_dir, "ls-files" })
			local first = vim.trim(ls):match("[^\n]+")
			if first then
				target = repo_dir .. "/" .. first
			else
				vim.fn.writefile({}, target)
			end
		end
		vim.cmd("edit " .. vim.fn.fnameescape(target))
	end)
end

function M.create_worktree()
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

	vim.ui.input({ prompt = "Branch name: " }, function(branch)
		if not branch or branch == "" then
			return
		end

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

		local new_file = worktree_path .. "/" .. rel_path
		if vim.fn.filereadable(new_file) ~= 1 then
			new_file = worktree_path .. "/README.md"
			if vim.fn.filereadable(new_file) ~= 1 then
				local ls_output = vim.fn.system({ "git", "-C", worktree_path, "ls-files" })
				local first = ls_output:match("[^\n]+")
				if first then
					new_file = worktree_path .. "/" .. first
				else
					new_file = worktree_path .. "/README.md"
				end
			end
		end
		vim.cmd("edit " .. vim.fn.fnameescape(new_file))
	end)
end

return M
