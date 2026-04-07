local M = {}

M.lang_to_REPL = {
	lua = "lua",
	javascript = "node",
	javascriptreact = "node",
	typescript = "node",
	typescriptreact = "node",
}

M.opts = {
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
	['git add --all; git commit -m "ongoing work" --no-verify; git push'] = true,
	["git-sync-all"] = true,
	["git-sync"] = true,
	pi = { cmd = "pi --provider github-copilot --model gpt-5.3-codex", tag = "agent" },
	pi_minimal = {
		cmd = "pi --no-extensions --no-skills --no-prompt-templates --no-themes --no-session --provider cerebras --model qwen-3-235b-a22b-instruct-2507",
		tag = "agent",
	},
	gemini = { cmd = "gemini", tag = "agent" },
	claude = { cmd = "claude", tag = "agent" },
	opencode = { cmd = "opencode", tag = "agent" },
}

M.default_by_tag = { agent = "pi_minimal" }

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
