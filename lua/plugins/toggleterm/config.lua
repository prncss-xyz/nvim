local personal = require("my.conds").personal
local work = require("my.conds").work
local notify = require("my.notify")

local ai_term = require("my.parameters").ai_config.chat == "toggleterm"

local tags_defaults_agent = personal("pi", "claude")

return {
	idle_timeout = 30000,
	packages = {
		tagger = function(key)
			if key:find("test") then
				return "test"
			end
		end,
	},

	on_idle = function(scope, key)
		local msg = string.format("%s in %s (idle)", key, scope)
		notify.notify(msg)
	end,

	lang_to_REPL = {
		lua = "lua",
		javascript = "node",
		javascriptreact = "node",
		typescript = "node",
		typescriptreact = "node",
	},

	tags_defaults = {
		agent = tags_defaults_agent,
	},

	-- TODO: make this accept tags
	default_terminal = ai_term and tags_defaults_agent or "shell",

	auto = {
		-- TODO: make this accept tags
		tags_defaults_agent,
	},

	commands = {
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
		shell = {},
		["home shell"] = {
			dir = vim.env.HOME,
			global = true,
		},
		diff = {
			cmd = require("my.diff").get_cmd(),
			close_on_exit = false,
		},
		repl = require("plugins.toggleterm.repl").get_REPL,
		gac = {
			cmd = "gac",
		},
		gacp = {
			cmd = "gacp",
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
			cmd = "p",
			tag = "agent",
		}),
		claude = ai_term and work({
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

	new = {
		pi = "new",
		opencode = "new",
		claude = "clear",
	},

	prompts = {
		todo = function()
			return {
				cr = true,
				"do this",
				require("plugins.toggleterm.agents").current_line_ref(),
				require("plugins.toggleterm.agents").current_line(),
			}
		end,
		fixme = function()
			return {
				"fix this",
				require("plugins.toggleterm.agents").current_line_ref(),
				require("plugins.toggleterm.agents").current_line(),
			}
		end,
		explain = function()
			return {
				cr = true,
				"explain this",
				require("plugins.toggleterm.agents").current_line_ref(),
				require("plugins.toggleterm.agents").current_line(),
			}
		end,
	},
}
