local personal = require("my.conds").personal
local notify = require("my.notify")
local prompt_utils = require("plugins.toggleterm.helpers.prompt")

local agent = personal("p", "claude")

return {
	agents = { "p", "claude", "agy" },
	min_runtime = 10000,
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
	tasks = {
		{
			name = "do",
			source = "task.md",
			cmd = { agent, "do this @{source}" },
			fork = false,
		},
		{
			name = "task",
			source = "task.md",
			target = "design.md",
			cmd = { agent, [[create the file {target} and write a broad design to implement @{source}]] },
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
		{ name = "ready" },
		{ name = "active" },
		{ name = "blocked" },
		{ name = "review" },
		{ name = "merging" },
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
		["artifacts"] = "create all artifacts inside {artifacts}/",
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
	lang_to_REPL = {
		lua = "lua",
		javascript = "node",
		javascriptreact = "node",
		typescript = "node",
		typescriptreact = "node",
	},
	commands = {
		yazi = { cmd = "yazi" },
		ddgr = {
			cmd = "ddgr",
			cwd = vim.env.HOME,
		},
		portless = {
			cmd = "portless",
			on_exit = "keep",
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
	},
	autostart = {},
}
