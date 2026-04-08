local M = {}

local personal = require("my.conds").personal
local work = require("my.conds").work

M.lang_to_REPL = {
	lua = "lua",
	javascript = "node",
	javascriptreact = "node",
	typescript = "node",
	typescriptreact = "node",
}

M.commands = {
	tilt = work({ cmd = "make tilt", global = true }),
	dev = { cmd = "pnpm run dev" },
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
	["commit ongoing work"] = 'git add --all; git commit -m "ongoing work" --no-verify; git push',
	["git-sync-all"] = personal(),
	["git-sync"] = personal({
    cmd = "git-sync",
    direction = "float",
  }),
	pi = personal({ cmd = "pi --provider github-copilot --model gpt-5.3-codex", tag = "agent" }),
	pi_minimal = personal({
		cmd = "pi --no-extensions --no-skills --no-prompt-templates --no-themes --no-session --provider cerebras --model qwen-3-235b-a22b-instruct-2507",
		tag = "agent",
	}),
	gemini = personal({ cmd = "gemini", tag = "agent" }),
	claude = { cmd = "claude", tag = "agent" },
	opencode = personal({ cmd = "opencode", tag = "agent" }),
}

M.default_by_tag = { agent = personal("gemini", "claude") }

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
function M.start(start)
	start("agent")
	start("tilt")
end

return M
