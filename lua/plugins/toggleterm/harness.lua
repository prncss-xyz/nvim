local M = {}

local function collect_input(prompt, callback)
	local mode = vim.fn.mode()
	if mode:match("[vV\22]") then
		local input = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
		if input ~= nil and vim.trim(input) ~= "" then
			callback(input)
		end
		return
	end

	vim.ui.input({ prompt = prompt }, function(input)
		if input ~= nil and vim.trim(input) ~= "" then
			callback(input)
		end
	end)
end

local SUMMARY_PROMPT = [==[
Your task is to describe the goal of the following prompt.
You must use at most 4 words. Only lowercase except for proper names. No punctuation.
Do not describe completion critaira.
Do not describe methodology or intermediate results.
Only describe the goal.

<task>
]==]

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

local function branch_name(input, callback)
	local root = vim.fs.root(0, ".git") or vim.uv.cwd()
	vim.notify("Naming branch...", vim.log.levels.INFO)
	vim.system({
		"p",
		"--no-tools",
		"--no-extensions",
		"--no-skills",
		"--no-context-files",
		"--model",
		"opencode-go/deepseek-v4-flash:off",
		"-p",
	}, { cwd = root, text = true, stdin = SUMMARY_PROMPT .. input .. "</task>" }, function(result)
		vim.schedule(function()
			assert(result.code == 0, result.stderr)
			local branch = sanitize_branch(result.stdout)
			assert(branch ~= "", "create-branch-name returned an empty name")
			existing_branches(function(seen)
				callback(find_free_branch(branch, seen), root)
			end)
		end)
	end)
end

local function create_artifact(input, filename)
	branch_name(input, function(branch, root)
		local path = vim.fs.joinpath(root, ".artifacts", branch, filename)
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		vim.fn.writefile(vim.split(input, "\n", { plain = true }), path)
		vim.cmd.edit(vim.fn.fnameescape(path))
	end)
end

function M.artifact_to_worktree(branch, opts)
	vim.notify("Creating worktree " .. branch .. "...", vim.log.levels.INFO)
	require("my.git").create_worktree(branch, function(_, worktree_path)
		opts.dir = worktree_path
		require("plugins.toggleterm.terms").focus(opts)
	end)
end

function M.prompt_to_artifact(prompt, filename)
	collect_input(prompt, function(input)
		create_artifact(input, filename)
	end)
end

function M.prompt_to_worktree(prompt, opts)
	collect_input(prompt, function(input)
		branch_name(input, function(branch)
			opts.cmd = opts.cmd .. prompt
			M.artifact_to_worktree(branch, opts)
		end)
	end)
end

return M
