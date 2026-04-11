local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal
local domain = require("my.parameters").domain
local ai = domain.ai
local ai_insert = require("my.parameters").ai_insert

-- TODO: augmentcode
local completion = personal("copilot", "copilot") -- "copilot" | "windsurf" |  "none"
local chat = personal("agentic", "sidekick") -- 'sidekick' | 'avante' | 'copilotchat' | 'claude' | 'agentic' | 'none'

return {
	{
		"zbirenbaum/copilot.lua",
		dependencies = {
			{
				"copilotlsp-nvim/copilot-lsp",
				init = function()
					vim.g.copilot_nes_debounce = 500
				end,
			},
		},
		opts = {
			filetypes = {
				markdown = false,
			},
			nes = {
				enabled = true,
				keymap = {
					accept_and_goto = ai_insert.nes,
					accept = false,
					dismiss = false,
				},
			},
		},
		keys = {
			{
				ai_insert.nes,
				function()
					local nes_api = require("copilot.nes.api")
					local result = nes_api.nes_apply_pending_nes()
					if result then
						nes_api.nes_walk_cursor_end_edit()
					end
				end,
				desc = "Copilot accept NES",
				mode = { "n", "x", "i" },
			},
			{
				ai_insert.clear,
				function()
					local touched = false
					local suggestion = require("copilot.suggestion")
					if suggestion.is_visible() then
						touched = true
						suggestion.dismiss()
					end
					if require("copilot-lsp.nes").clear() then
						touched = true
					end
					if not touched then
						vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
						vim.lsp.buf.format({
							async = false,
							filter = function(client)
								return not vim.tbl_contains({
									"lua_ls",
									"vtsls",
								}, client.name)
							end,
						})
					end
				end,
				desc = "Coplot Clear suggestions or Leave insert mode",
				mode = { "n", "v", "i" },
			},
		},
		cmd = { "Copilot" },
		event = "InsertEnter",
		enabled = completion == "copilot" or chat == "copilotchat",
		cond = not_vscode,
	},
	{
		"carlos-algms/agentic.nvim",
		opts = {
			provider = "opencode-acp",
			session_manager = {
				get_session_id = function()
					return vim.fn.sha256(vim.fn.getcwd())
				end,
				storage_path = vim.fn.stdpath("data") .. "/agent_sessions/",
			},
		},
		keys = {
			{
				"okk",
				function()
					require("agentic").toggle()
				end,
				desc = "Toggle Agentic Chat",
			},
			{
				"ok" .. "i",
				function()
					require("agentic").add_selection_or_file_to_context()
				end,
				mode = { "n", "v" },
				desc = "Add file or selection to Agentic to Context",
			},
			{
				"ok" .. "a",
				function()
					require("agentic").new_session()
				end,
				desc = "New Agentic Session",
			},
			{
				"ok" .. "r",
				function()
					require("agentic").restore_session()
				end,
				desc = "Agentic Restore session",
			},
		},
		enabled = chat == "agentic",
		cond = not_vscode,
	},
	{
		"Exafunction/windsurf.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			enable_cmp_source = false,
			virtual_text = {
				enabled = true,
				key_bindings = {
					accept = ai_insert.accept,
					next = ai_insert.next,
					prev = ai_insert.prev,
					clear = ai_insert.clear,
				},
			},
		},
		name = "codeium",
		event = "InsertEnter",
		cmd = "Codeium",
		enabled = completion == "windsurf",
		cond = not_vscode,
	},
	{
		"coder/claudecode.nvim",
		dependencies = { "folke/snacks.nvim" },
		config = true,
		keys = {
			{
				ai_insert.toggle,
				"<cmd>ClaudeCode<cr>",
				mode = { "n", "i", "t" },
				desc = "ClaudeCode Chat",
			},
			{ ai .. "r", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
			{ ai .. "c", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
			{ ai .. "m", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
			{ ai .. "e", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
			{ ai .. "e", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude" },
			{ ai .. "o", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept diff" },
			{ ai .. "t", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny diff" },
		},
		enabled = chat == "claude",
	},
	{
		"NickvanDyke/opencode.nvim",
		opts = {
			prompts = {
				ask_append = { prompt = "", ask = true }, -- Handy to insert context mid-prompt. Simpler than exposing every context as a prompt by default.
				ask_this = { prompt = "@this: ", ask = true, submit = true },
				diagnostics = { prompt = "Explain @diagnostics", submit = true },
				diff = {
					prompt = "Review the following git diff for correctness and readability: @diff",
					submit = true,
				},
				document = { prompt = "Add comments documenting @this", submit = true },
				explain = { prompt = "Explain @this and its context", submit = true },
				fix = { prompt = "Fix @diagnostics", submit = true },
				implement = { prompt = "Implement @this", submit = true },
				optimize = { prompt = "Optimize @this for performance and readability", submit = true },
				review = { prompt = "Review @this for correctness and readability", submit = true },
				test = { prompt = "Add tests for @this", submit = true },
			},
		},
		config = function(_, opts)
			vim.g.opencode_opts = opts
		end,
		keys = {
			{
				ai_insert.toggle,
				function()
					require("opencode").toggle()
				end,
				mode = { "n", "i", "t" },
				desc = "Opencode Chat",
			},
			{
				ai .. "i",
				function()
					require("opencode").ask()
				end,
				mode = { "n", "x" },
				desc = "Opencode Ask Prompt",
			},
			{
				ai .. "a",
				function()
					require("opencode").select()
				end,
				mode = { "n", "x" },
				desc = "Opencode Prompt",
			},
		},
		enabled = chat == "opencode",
		cond = not_vscode,
	},
}
