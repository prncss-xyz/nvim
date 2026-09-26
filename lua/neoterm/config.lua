local personal = require("my.conds").personal
local work = require("my.conds").work
local dirs = require("my.parameters").dirs
local do_not_replace_types = require("my.parameters").open_files_do_not_replace_types
local notify = require("my.notify")
local prompt_utils = require("neoterm.helpers.prompt")

return {
	agent = {
		list = { "pi", "codex", "agy", "claude", "fx" },
		query = personal(
			"p --no-tools --no-extensions --no-skills --no-context-files --model opencode-go/deepseek-v4-flash:off -p",
			"claude -p --model haiku --disable-slash-commands --tools="
		),
		alias = {
			deep = {
				codex = {
					model = "sol-6",
					effort = "low",
				},
				pi = {
					provider = "openai-codex",
					model = "gpt-sol-6",
					effort = "low",
				},
				claude = {
					model = "opus",
					effort = "low",
				},
			},
			fast = {
				codex = {
					model = "luna-6",
					effort = "low",
				},
				pi = {
					provider = "opencode-go",
					model = "glm-5.3-flash",
					effort = "low",
				},
				claude = {
					model = "haiku",
					effort = "low",
				},
			},
		},
	},
	rooter_patterns = { ".git", ".hg", ".svn" },
	default_branches = { "main", "master" },
	dirs = {
		projects = dirs.projects,
		artifacts = dirs.artifacts,
	},
	min_runtime = 10000,
	open_files_do_not_replace_types = do_not_replace_types,
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
	filter = {
		keybindings = {
			["<C-n>"] = "next",
			["<Down>"] = "next",
			["<C-p>"] = "previous",
			["<Up>"] = "previous",
			["<CR>"] = "accept",
		},
	},
	term_panel = {
		width = personal(40, 60),
		keybindings = {
			["é"] = "filter",
			["<CR>"] = "focus",
			r = "restart",
			x = "kill",
			n = "create",
			q = "close",
			h = "help",
		},
	},
	task_panel = {
		width = personal(40, 60),
		keybindings = {
			["é"] = "filter",
			c = "create",
			n = "next_mode",
			p = "previous_mode",
			r = "set_root",
			u = "up_root",
			["<CR>"] = "open",
			x = "delete",
			q = "close",
			h = "help",
		},
	},
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
				tag = "agent",
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
				tag = "agent",
				title = "{step}",
				prompt = [[create the file {target} and write a broad design to implement @{source}]],
			},
			fork = false,
		},
	},
	tasks = {
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
		default_status = "inbox",
		default_mode = "focus",
		blocking = {
			status = "blocked",
			unblock = { "done" },
		},
		modes = {
			all = vim.tbl_filter(function(status)
				return status ~= false
			end, {
				"draft",
				"maybe",
				"later 2",
				"later 1",
				"later 0",
				"inbox",
				"explore",
				"ready",
				"active",
				"blocked",
				"review",
				"merging",
				work("report:done", false),
				"done",
				work("report:aborted", false),
				"aborted",
			}),
			inbox = { "inbox" },
			focus = { "explore", "ready", "active" },
			standup = work({ "export", "ready", "active", "report:done", "report:aborted" }),
		},
	},
	templates = {
		"agents",
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
	middlewares = {
		"agents",
		"sandbox",
	},
	commands = {
		yazi = { cmd = "yazi" },
		ddgr = {
			cmd = "ddgr",
			cwd = vim.env.HOME,
		},
		portless = {
			cmd = "portless",
			exit_policy = "keep",
		},
		["run current"] = function()
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
}
