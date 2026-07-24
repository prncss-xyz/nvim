local personal = require("my.conds").personal
local work = require("my.conds").work
local notify = require("my.notify")

local ai_term = require("my.parameters").ai_config.chat == "toggleterm"

local screen_manifests = {
	pi = {
		default_status = "idle",
		rules = {
			{
				id = "working_literal",
				status = "working",
				priority = 100,
				region = "whole_recent",
				contains = { "Working..." },
			},
		},
	},
	claude = {
		default_status = "idle",
		rules = {
			{
				id = "permission_prompt",
				status = "blocked",
				priority = 900,
				region = "after_last_horizontal_rule",
				any = {
					{ contains = { "do you want to proceed?" } },
					{ contains = { "waiting for permission" } },
					{ contains = { "tab to amend" } },
					{ contains = { "esc to cancel", "enter to select" } },
				},
			},
			{
				id = "working_interrupt_hint",
				status = "working",
				priority = 500,
				region = "bottom_non_empty_lines(5)",
				any = {
					{ contains = { "esc to interrupt" } },
					{ contains = { "ctrl+c to interrupt" } },
				},
			},
			{
				id = "prompt",
				status = "idle",
				priority = 100,
				region = "prompt_box_body",
				line_regex = { [[^\s*❯]] },
			},
		},
	},
}

return {
	min_runtime = 10000,
	packages = {
		tagger = function(key)
			if key:find("test") then
				return "test"
			end
		end,
	},

	on_status = function(item)
		local msg = string.format("%s in %s (%s)", item.key, item.dir, item.status)
		notify.notify(msg)
	end,

	lang_to_REPL = {
		lua = "lua",
		javascript = "node",
		javascriptreact = "node",
		typescript = "node",
		typescriptreact = "node",
	},

	commands = {
		tsterr = {
			cmd = "tsterr",
			on_exit = "restart",
		},
		ddgr = {
			cmd = "ddgr",
			dir = vim.env.HOME,
		},
		portless = {
			cmd = "portless",
			on_exit = "keep",
		},
		tilt = work({
			cmd = "make tilt",
			on_exit = "keep",
			global = true,
		}),
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
			cmd = 'git add --all; git commit -m "ongoing work" --no-verify',
			on_exit = "keep",
		},
		["commit ongoing work and push"] = {
			cmd = 'git add --all; git commit -m "ongoing work" --no-verify; git push',
			on_exit = "keep",
		},
		["git-sync-all"] = personal({
			cmd = "git-sync-all",
			on_exit = "keep",
		}),
		["git-sync"] = personal({
			cmd = "git-sync",
			on_exit = "keep",
		}),
		antigravity = personal({
			cmd = "agy",
			tag = "agent",
		}),
		pi = ai_term and personal({
			priority = 3,
			cmd = "p",
			tag = "agent",
			screen_manifest = screen_manifests.pi,
		}),
		claude = ai_term and work({
			priority = 2,
			cmd = "claude",
			tag = "agent",
			screen_manifest = screen_manifests.claude,
		}),
		["make daily-login"] = function()
			if vim.fn.filereadable(vim.fn.getcwd() .. "/Makefile") == 1 then
				return { cmd = "make daily-login" }
			else
				return nil
			end
		end,
		["make tilt"] = function()
			if vim.fn.filereadable(vim.fn.getcwd() .. "/Makefile") == 1 then
				return { cmd = "make tilt" }
			else
				return nil
			end
		end,
		["chezmoi apply"] = function()
			if
				vim.fn.executable("chezmoi") == 1
				and vim.fn.getcwd() == vim.trim(vim.fn.system("chezmoi source-path"))
			then
				return { cmd = "chezmoi apply" }
			else
				return nil
			end
		end,
	},
	prompts = {
		["do this"] = "do this",
		["explain this"] = "explain this",
		["curry this"] = "curry this",
	},
	autostart = {
		{ key = "ddgr" },
		{ tag = "agent" },
	},
}
