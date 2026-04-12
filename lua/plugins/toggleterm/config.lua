local M = {}

local personal = require("my.conds").personal
local work = require("my.conds").work

local ai_term = require("my.parameters").ai_config.chat == "toggleterm"

M.lang_to_REPL = {
	lua = "lua",
	javascript = "node",
	javascriptreact = "node",
	typescript = "node",
	typescriptreact = "node",
}

M.commands = {
	tilt = work({
		cmd = "make tilt",
		close_on_exit = false,
		global = true,
		auto = true,
	}),
	dev = {
		cmd = "pnpm run dev",
		close_on_exit = false,
	},
	test = { cmd = "pnpm run test --watch" },
	current = function()
		return { dir = vim.fn.expand("%:p:h") }
	end,
	term_e = {},
	term_r = {},
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
	pi = personal({
		cmd = "pi --provider opencode --model big-pickle",
		auto = ai_term,
		tag = "agent",
	}),
	pi_minimal = personal({
		cmd = "pi --continue --no-extensions --no-skills --no-prompt-templates --no-themes --no-session --provider cerebras --model qwen-3-235b-a22b-instruct-2507",
		tag = "agent",
	}),
	gemini = personal({
		cmd = "gemini --resume",
		tag = "agent",
	}),
	claude = {
    cmd = "claude --continue",
    tag = "agent",
    auto = work() and ai_term
  },
	opencode = personal({ cmd = "opencode --continue", tag = "agent" }),
	kilo = personal({ cmd = "kilo --continue", tag = "agent" }),
}

M.prompts = {
	todo = function()
		return {
			cr = true,
			"do this",
			require("plugins.toggleterm.agents").current_line_ref(),
			require("plugins.toggleterm.agents").current_line_content(),
		}
	end,
	fixme = function()
		return {
			"fix this",
			require("plugins.toggleterm.agents").current_line_ref(),
			require("plugins.toggleterm.agents").current_line_content(),
		}
	end,
	explain = function()
		return {
			cr = true,
			"explain this",
			require("plugins.toggleterm.agents").current_line_ref(),
			require("plugins.toggleterm.agents").current_line_content(),
		}
	end,
}

return M
