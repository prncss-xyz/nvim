local M = {}

local personal = require("my.conds").personal
local work = require("my.conds").work
local notify = require("my.notify")

local ai_term = require("my.parameters").ai_config.chat == "toggleterm"

M.idle_timeout = 2000
M.default_terminal = "term_e" -- Default terminal name
M.packages = {
	tagger = function(key)
		if key:find("test") then
			return "test"
		end
	end,
}

M.on_idle = function(scope, key)
	local msg = string.format("%s in %s (idle)", key, scope)
	notify.notify(msg)
end

M.lang_to_REPL = {
	lua = "lua",
	javascript = "node",
	javascriptreact = "node",
	typescript = "node",
	typescriptreact = "node",
}

M.start = {
	"tilt",
	"pnpm run dev:test",
	ai_term and personal("pi", "claude"),
}

M.commands = {
	tilt = work({
		cmd = "make tilt",
		close_on_exit = false,
		global = true,
		auto = true,
	}),
	current = function()
		return { dir = vim.fn.expand("%:p:h") }
	end,
	term_e = {},
	term_r = {
		dir = vim.env.HOME,
		global = true,
	},
	diff = {
		cmd = require("my.diff").get_cmd(),
		close_on_exit = false,
	},
	repl = require("plugins.toggleterm.repl").get_REPL,
	["commit ongoing work"] = {
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
	pi = ai_term and personal({
		cmd = "pi -c",
		auto = ai_term,
		tag = "agent",
	}),
	gemini = ai_term and personal({
		cmd = "gemini --resume",
		tag = "agent",
	}),
	claude = ai_term and {
		cmd = "claude --continue",
		tag = "agent",
		auto = work() and ai_term,
	},
	opencode = ai_term and personal({ cmd = "opencode --continue", tag = "agent" }),
	kilo = ai_term and personal({ cmd = "kilo --continue", tag = "agent" }),
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
		if vim.fn.executable("chezmoi") == 1 and vim.fn.getcwd() == vim.trim(vim.fn.system("chezmoi source-path")) then
			return { cmd = "chezmoi apply" }
		else
			return nil
		end
	end,
}

M.new = {
	pi = "new",
	opencode = "new",
	claude = "clear",
	kilo = "new",
	gemini = "clear",
}

M.prompts = {
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
}

return M
