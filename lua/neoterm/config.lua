local personal = require("my.conds").personal
local work = require("my.conds").work
local dirs = require("my.parameters").dirs
local notify = require("my.notify")
local prompt_utils = require("neoterm.helpers.prompt")

local agent = personal("pi", "claude")
return {
	rooter_patterns = { ".git", ".hg", ".svn" },
	default_branches = { "main", "master" },
	dirs = {
		projects = dirs.projects,
		artifacts = dirs.notes .. "/dev/artifacts",
	},
	min_runtime = 10000,
	browser = (function()
		local value
		return function()
			if value then
				return value
			end

			local uname = vim.loop.os_uname()
			local os = uname.sysname
			if os == "Darwin" then
				value = "open"
			elseif os:find("Windows") or (os == "Linux" and uname.release:lower():find("microsoft")) then
				value = 'cmd.exe /c start ""'
			else
				value = "xdg-open"
			end
			return value
		end
	end)(),
	ai_query = personal(
		"p --no-tools --no-extensions --no-skills --no-context-files --model opencode-go/deepseek-v4-flash:off -p",
		"claude -p --model haiku --disable-slash-commands --tools="
	),
	create_task_name = [==[
Generate a concise git branch name based on the task description.

Rules:
- Keep it short: 1-3 words, max 4 if necessary
- Focus on the core task/feature, not implementation details
- Non coding tasks should start with "todo-"
- Coding tasks should start with conventional commits prefixes

Examples of good branch names:
- "Schedule a meeting with Amanda" → todo-meeting-amanda
- "Add dark mode toggle" → feat-dark-mode
- "Fix the search results not showing" → fix-search
- "Refactor the authentication module" → refactor-auth
- "Add CSV export to reports" → feat-export-csv
- "Shell completion is broken" → feat-shell-completion

Output ONLY the branch name, nothing else.

<task>{input}</task>
]==],
	create = require("my.create").create,
	bdelete = function(bufnr)
		Snacks.bufdelete.delete(bufnr)
	end,
	notify = personal() and function(title, message)
		vim.system({ "notify-send", title, message }, { detach = true })
	end or function(title, message)
		vim.system({
			"osascript",
			"-e",
			"on run argv",
			"-e",
			"display notification (item 2 of argv) with title (item 1 of argv)",
			"-e",
			"end run",
			"--",
			title,
			message,
		}, { detach = true })
	end,
	panel = { width = personal(40, 60) },
	git_status_icons = {
		ahead = "⇡",
		behind = "⇣",
		conflicted = "=",
		deleted = "✘",
		diverged = "⇕",
		modified = "!",
		renamed = "»",
		staged = "+",
		stashed = "$",
		untracked = "?",
	},
	steps = {
		{
			name = "do",
			source = "task.md",
			command = {
				agent = agent,
				title = "{step}",
				prompt = "do this @{source}",
			},
			fork = false,
		},
		{
			name = "task",
			source = "task.md",
			target = "design.md",
			command = {
				agent = agent,
				title = "{step}",
				prompt = [[create the file {target} and write a broad design to implement @{source}]],
			},
			fork = false,
		},
	},
	default_status = "draft",
	block_as = "blocked",
	unblock_with = { "done" },
	status = {
		{ name = "draft" },
		{ name = "maybe" },
		{ name = "later" },
		{
			name = "explore",
			focus = true,
		},
		{
			name = "ready",
			focus = true,
		},
		{
			name = "active",
			focus = true,
		},
		{ name = "blocked" },
		{ name = "review" },
		{ name = "merging" },
		{ name = "done" },
		{ name = "aborted" },
	},
	templates = {
		"steps",
		"chezmoi",
		"git_sync",
		"make",
		"mise",
		"npm",
	},
	prompts = {
		["artifacts"] = "{artifacts}/",
		["nvim message"] = "{nvim_messages}",
		["do"] = "do this: {position}",
		["explain"] = "explain this: {position}",
		["curry"] = "curry this: {position}",
		["where in the codebase "] = prompt_utils.sender(),
		["anchor"] = [[We are developing the contents of an artifact file. When I ask you a question or give you an enquiry, update this file instead of answering me in the conversation. Add the bare minimum amount of text to answer the question while quoting your sources. The file is {path}.

]],
	},
	on_status = function(item)
		if item.changed then
			notify.notify(string.format("%s in %s (%s)", item.key, item.cwd, item.status))
		end
	end,
	on_working_change = function(working)
		require("neoterm.helpers.inhibit_sleep").set(working)
	end,
	commands = {
		pi = personal({
			agent = "pi",
			priority = 3,
		}),
		agy = personal({
			agent = "agy",
			priority = 2,
		}),
		claude = work({
			agent = "claude",
			priority = 1,
		}),
		yazi = { cmd = "yazi" },
		ddgr = {
			cmd = "ddgr",
			cwd = vim.env.HOME,
		},
		portless = {
			cmd = "portless",
			exit_policy = "keep",
		},
		current = function()
			return { cwd = vim.fn.expand("%:p:h") }
		end,
		shell = {
			priority = 1,
		},
		["home shell"] = {
			cwd = vim.env.HOME,
		},
		diff = {
			cmd = require("my.diff").get_cmd(),
			exit_policy = "keep",
		},
		repl = require("my.repl").get_REPL,
		gac = {
			cmd = "gac",
			exit_policy = "keep",
		},
		gacp = {
			cmd = "gacp",
			exit_policy = "keep",
		},
		["git push"] = { cmd = "git push", exit_policy = "keep" },
		["git pull"] = { cmd = "git pull", exit_policy = "keep" },
		["git rebase master"] = { cmd = "git rebase master", exit_policy = "keep" },
		["commit ongoing work"] = {
			cmd = 'git add --all; git commit -m "changes from $(uname -n) on $(date)" --no-verify',
			exit_policy = "keep",
		},
		["commit ongoing work and push"] = {
			cmd = 'git add --all; git commit -m "changes from $(uname -n) on $(date)" --no-verify; git push',
			exit_policy = "keep",
		},
		["git-sync-all"] = personal({
			cmd = "git-sync-all",
			exit_policy = "keep",
		}),
	},
	autostart = {},
}
