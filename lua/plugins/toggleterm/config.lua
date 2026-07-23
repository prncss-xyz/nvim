local personal = require("my.conds").personal
local work = require("my.conds").work
local notify = require("my.notify")

local ai_term = require("my.parameters").ai_config.chat == "toggleterm"

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
		ddgr = {
			cmd = "ddgr",
			dir = vim.env.HOME,
		},
		portless = {
			cmd = "portless",
			close_on_exit = false,
		},
		tilt = work({
			cmd = "make tilt",
			close_on_exit = false,
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
			close_on_exit = false,
		},
		repl = require("plugins.toggleterm.repl").get_REPL,
		gac = {
			cmd = "gac",
			close_on_exit = false,
		},
		gacp = {
			cmd = "gacp",
			close_on_exit = false,
		},
		["commit ongoing work"] = {
			cmd = 'git add --all; git commit -m "ongoing work" --no-verify',
			close_on_exit = false,
		},
		["commit ongoing work and push"] = {
			cmd = 'git add --all; git commit -m "ongoing work" --no-verify; git push',
			close_on_exit = false,
		},
		["git-sync-all"] = personal({
			cmd = "git-sync-all",
			close_on_exit = false,
		}),
		["git-sync"] = personal({
			cmd = "git-sync",
			close_on_exit = false,
		}),
		antigravity = personal({
			cmd = "agy",
			tag = "agent",
		}),
		pi = ai_term and personal({
			priority = 3,
			cmd = "p",
			tag = "agent",
		}),
		claude = ai_term and work({
			priority = 2,
			cmd = "claude",
			tag = "agent",
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
