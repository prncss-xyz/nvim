local personal = require("my.conds").personal
local work = require("my.conds").work
local dirs = require("my.parameters").dirs
local do_not_replace_types = require("my.parameters").open_files_do_not_replace_types
local notify = require("my.notify")
local prompt_utils = require("neoterm.helpers.prompt")

local env = {
	NEOMUX_CTX = [[artifacts, such as plans, reports, screenshots, scripts related to the current tasks goes in {artifacts}
]],
}

local agent_command = {
	sandbox = "bwrap",
	varlock = "~/.config/varlock/env.agent.schema",
	env = env,
}

local agent_variants = { "claude", "codex" }

local agents = personal({
	{
		name = "codex",
		command = agent_command,
		alias = {
			extra = { model = "GPT-6-Astra", effort = "high" },
			deep = { model = "GPT-6.1-Sol", effort = "low" },
			medium = { model = "GPT-6.1 Terra", effort = "low" },
			fast = { model = "GPT-6-Luna", effort = "low" },
		},
	},
	{
		name = "pi",
		command = agent_command,
		alias = {
			deep = { provider = "openai-codex", model = "gpt-6.1-sol", effort = "low" },
			fast = { provider = "openai-codex", model = "gpt-6-luna", effort = "low" },
		},
	},
	{ name = "agy", command = agent_command },
	{
		name = "fx",
		command = agent_command,
		alias = {
			deep = { provider = "openai-codex", model = "gpt-6.1-sol", effort = "low" },
			fast = { provider = "openai-codex", model = "gpt-6-luna", effort = "low" },
		},
	},
	{
		name = "claude",
		command = agent_command,
		alias = {
			deep = { model = "opus", effort = "low" },
			medium = { model = "sonnet", effort = "low" },
			fast = { model = "haiku", effort = "low" },
		},
	},
}, {
	{
		name = "claude",
		command = { env = env },
		alias = {
			deep = { model = "opus", effort = "low" },
			fast = { model = "haiku", effort = "low" },
		},
	},
})

return {
	llm_query = personal(
		--"p --no-tools --no-extensions --no-skills --no-context-files --model opencode-go/deepseek-v4-flash:off -p",
		"codex exec --model gpt-6-luna --sandbox read-only -",
		"claude -p --model haiku --disable-slash-commands --tools="
	),
	agents = agents,
	rooter_patterns = { ".git", ".hg", ".svn" },
	on_zone = function(zone)
		require("my.theme_utils").set_zone_theme(zone)
	end,
	default_branches = { "main", "master" },
	dirs = {
		projects = dirs.projects,
		artifacts = dirs.artifacts,
	},
	min_runtime = 10000,
	open_files_do_not_replace_types = do_not_replace_types,
	browser = vim.ui.open,
	-- browser = require("my.browser").visit,
	create = require("my.create").create,
	bdelete = function(bufnr)
		Snacks.bufdelete.delete(bufnr)
	end,
	notify = function(title, message)
		notify.notify(message, { title = title })
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
			name = "fork",
			source = "task.md",
			target = "merge.txt",
			command = { tag = "open" },
			fork = true,
		},
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
			name = "do-fork",
			source = "task.md",
			target = "merge.txt",
			command = {
				tag = "agent",
				title = "{step}",
				prompt = "do this @{source}",
			},
			fork = true,
		},
		{
			name = "plan",
			source = "task.md",
			target = { "plan.md", "merge.txt" },
			variants = agent_variants,
			command = {
				tag = "agent",
				agent = "{variant}",
				title = "{step}",
				skill = "plannify",
				prompt = "@{source}",
			},
			fork = true,
		},
		{
			name = "decompose",
			source = { "task.md", "plan.md" },
			variants = agent_variants,
			command = {
				tag = "agent",
				agent = "{variant}",
				title = "{step}",
				skill = "{name}",
				prompt = "@{source}",
			},
			fork = true,
		},
		{
			name = "api-contract",
			source = { "task.md", "plan.md" },
			target = { "api-contract.md", "walkthrough.md", "merge.txt" },
			variants = agent_variants,
			command = {
				tag = "agent",
				agent = "{variant}",
				title = "{step}",
				skill = "{name}",
				prompt = "@{source}",
			},
			fork = true,
		},
		{
			name = "implementation",
			source = { "task.md", "plan.md" },
			target = { "implementation.md", "merge.txt" },
			variants = agent_variants,
			command = {
				tag = "agent",
				agent = "{variant}",
				title = "{step}",
				skill = "{name}",
				prompt = "@{source}",
			},
			fork = true,
		},
		{
			name = "retro",
			source = "implementation.md",
			target = { "retro.md", "merge.txt" },
			variants = agent_variants,
			command = {
				tag = "agent",
				agent = "{variant}",
				title = "{step}",
				skill = "{name}",
				prompt = "@{source}",
			},
			fork = true,
		},
		{
			name = "info",
			target = "merge.txt",
			fork = true,
			on_success = function(vars)
				require("neoterm.git").ensure_worktree(vars.cwd, function(ok)
					if ok then
						local branch = assert(
							require("neoterm.terms.artifacts.paths").current_branch(vars.cwd),
							"Cannot determine destination branch"
						)
						vim.notify(
							string.format(
								"Source: %s\nDestination: %s\n\n%s",
								vars.source_branch,
								branch,
								vars.message or ""
							),
							vim.log.levels.INFO,
							{ title = "Step info" }
						)
					end
				end)
			end,
		},
		{
			name = "diff",
			target = "merge.txt",
			fork = true,
			on_success = function(vars)
				require("neoterm.git").ensure_worktree(vars.cwd, function(ok)
					if ok then
						require("neoterm.helpers.ensure_dir").ensure_dir(vars.cwd)
						require("plugins.neotree.git_status").open(vars.source_branch, vars.cwd)
					end
				end)
			end,
		},
		{
			name = "merge",
			source = "walkthrough.md",
			command = {
				confirm = true,
				cmd = { "merge-from-current", "{source_branch}", "{message}" },
				exit_policy = "keep",
			},
			on_success = function(vars, output)
				local commit = assert(output.last_line(), "Merge command did not output a commit hash")
				assert(commit:match("^%x+$"), "Merge command output is not a commit hash")
				local source = vars.source:sub(2, -2):gsub("^~", function()
					return vim.env.HOME
				end)
				local identity = require("neoterm.terms.artifacts.paths").source(source)
				local prefix = vim.fs.basename(source):sub(1, -#identity.source - 1)
				local task = vim.fs.joinpath(identity.folder, prefix .. "task.md")
				local merge = vim.fs.joinpath(identity.folder, prefix .. "merge.txt")
				assert(vim.fn.writefile({ commit }, merge, "b") == 0, "Could not write merge artifact")
				local yaml = require("neoterm.yaml")
				local frontmatter = yaml.read_file(task)
				frontmatter.status = "done"
				yaml.write_file(task, frontmatter)
			end,
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
				"maybe",
				"later 2",
				"later 1",
				"later 0",
				"explore",
				"blocked",
				"inbox",
				"ready",
				"active",
				"review",
				"merging",
				work("report:done", false),
				"done",
				work("report:aborted", false),
				"aborted",
				personal("failed", false),
			}),
			inbox = { "inbox" },
			focus = { "blocked", "explore", "ready", "active" },
			standup = work({ "export", "ready", "active", "report:done", "report:aborted" }),
		},
	},
	templates = {
		"agents",
		"chezmoi",
		"git_sync",
		"make",
		"mise",
		"npm",
		"scripts",
	},
	prompts = {
		["artifacts"] = "{artifacts}/",
		["nvim message"] = "{nvim_messages}",
		["do"] = "do this: {position}",
		["explain"] = "explain this: {position}",
		["todo"] = "Implement this TODO comment: {position}",
		["Find where that thing is implemented. Answer with preferable just one file path and line citations."] = prompt_utils.sender(),
		["debrief"] = "Tell me the decisions you made during this session based on your own.",
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
		"varlock",
	},
	default_command = agents[1].name,
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
		shell = {},
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
		["gac --retry"] = {
			cmd = "gac --retry",
			exit_policy = "keep",
		},
		gacp = {
			cmd = "gacp",
			exit_policy = "keep",
		},
		["gacp --retry"] = {
			cmd = "gac; --retry",
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
