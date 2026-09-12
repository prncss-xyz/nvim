local personal = require("my.conds").personal
local work = require("my.conds").work
local notify = require("my.notify")
local prompt_utils = require("plugins.toggleterm.prompt_utils")

return {
	agents = { "p", "claude", "agy" },
	min_runtime = 10000,
	ai_query = personal(
		"p --no-tools --no-extensions --no-skills --no-context-files --model opencode-go/deepseek-v4-flash:off -p",
		"claude -p --model haiku --bare --disable-slash-commands --tools="
	),
	create = require("my.create").create,
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
	panel = {
		width = 40,
	},
	tasks = {
		{
			source = "plan",
			cmd = "pi -p /implement @%q",
			fork = true,
		},
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
		["do"] = "do this: {position}",
		["explain"] = "explain this: {position}",
		["curry"] = "curry this: {position}",
		["where in the codebase "] = prompt_utils.sender(),
		["task"] = prompt_utils.create_artifact("index.md"),
		["anchor"] = [[We are developing the contents of an artifact file. When I ask you a question or give you an enquiry, update this file instead of answering me in the conversation. Add the bare minimum amount of text to answer the question while quoting your sources. The file is {path}.

]],
	},

	on_status = function(item)
		local msg = string.format("%s in %s (%s)", item.key, item.dir, item.status)

		local fd = io.open(vim.env.HOME .. "/neomux.logs", "a")
		if fd then
			fd:write(string.format("[%s] %s\n", os.date("%Y-%m-%d %H:%M:%S"), msg))
			fd:close()
		end

		if item.changed then
			notify.notify(msg)
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
