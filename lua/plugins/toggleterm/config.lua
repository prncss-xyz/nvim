local personal = require("my.conds").personal
local notify = require("my.notify")
local prompt_utils = require("plugins.toggleterm.prompt_utils")

local agent = personal("p ", "claude ")

return {
	agents = { "p", "claude", "agy" },
	min_runtime = 10000,
	ai_query = personal(
		"p --no-tools --no-extensions --no-skills --no-context-files --model opencode-go/deepseek-v4-flash:off -p",
		"claude -p --model haiku --bare --disable-slash-commands --tools="
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
	notify = personal(function(title, message)
		vim.system({ "notify-send", title, message }, { detach = true })
	end, function(title, message)
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
	end),
	panel = { width = personal(40, 60) },
	tasks = {
		{
			name = "do",
			source = "task.md",
			cmd = agent .. "do this @{source}",
			fork = false,
		},
		{
			name = "task",
			source = "task.md",
			target = "design.md",
			cmd = agent .. [[create the file {target} and write a broad design to implement @{source}]],
			fork = false,
		},
	},
	default_status = "draft",
	block_as = "blocked",
	unblock_with = { "done" },
	status = {
		{ name = "draft" },
		{
			name = "ready",
			files = { "design.md" },
		},
		{ name = "active" },
		{ name = "blocked" },
		{ name = "verify" },
		{ name = "done" },
		{ name = "aborted" },
	},
	templates = {
		"agents",
		"artifacts",
		"chezmoi",
		"git_sync",
		"make",
		"mise",
		"npm",
	},
	prompts = {
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
			notify.notify(string.format("%s in %s (%s)", item.key, item.dir, item.status))
		end
	end,

	lang_to_REPL = {
		lua = "lua",
		javascript = "node",
		javascriptreact = "node",
		typescript = "node",
		typescriptreact = "node",
	},

	commands = {
		ddgr = {
			cmd = "ddgr",
			dir = vim.env.HOME,
		},
		portless = {
			cmd = "portless",
			on_exit = "keep",
		},
		current = function()
			return { dir = vim.fn.expand("%:p:h") }
		end,
		shell = {
			priority = 1,
		},
		["home shell"] = {
			dir = vim.env.HOME,
		},
		diff = {
			cmd = require("my.diff").get_cmd(),
			on_exit = "keep",
		},
		repl = require("plugins.toggleterm.repl").get_REPL,
		gac = {
			cmd = "gac",
			on_exit = "keep",
		},
		gacp = {
			cmd = "gacp",
			on_exit = "keep",
		},
		["git push"] = { cmd = "git push", on_exit = "keep" },
		["git pull"] = { cmd = "git pull", on_exit = "keep" },
		["git rebase master"] = { cmd = "git rebase master", on_exit = "keep" },
		["commit ongoing work"] = {
			cmd = 'git add --all; git commit -m "changes from $(uname -n) on $(date)" --no-verify',
			on_exit = "keep",
		},
		["commit ongoing work and push"] = {
			cmd = 'git add --all; git commit -m "changes from $(uname -n) on $(date)" --no-verify; git push',
			on_exit = "keep",
		},
		["git-sync-all"] = personal({
			cmd = "git-sync-all",
			on_exit = "keep",
		}),
		[":make daily-login"] = function()
			if vim.fn.filereadable(vim.fn.getcwd() .. "/Makefile") == 1 then
				return { cmd = "make daily-login" }
			else
				return nil
			end
		end,
		[":make tilt"] = function()
			if vim.fn.filereadable(vim.fn.getcwd() .. "/Makefile") == 1 then
				return { cmd = "make tilt" }
			else
				return nil
			end
		end,
	},
	autostart = {},
}
