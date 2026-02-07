local not_vscode = require("my.conds").not_vscode
local personal = require("my.conds").personal
local domain = require("my.parameters").domain
local pick = domain.pick
local ai = domain.ai
local ai_insert = require("my.parameters").ai_insert
local reverse = require("my.parameters").reverse

-- TODO: augmentcode
local completion = personal("copilot", "copilot") -- "copilot" | "windsurf" |  "none"
local chat = personal("sidekick", "copilotchat") -- 'sidekick' | 'avante' | 'copilotchat' | 'claude' | 'none'

return {
	{
		name = "amazonq",
		url = "https://github.com/awslabs/amazonq.nvim.git",
		opts = {
			ssoStartUrl = "https://view.awsapps.com/start", -- Authenticate with Amazon Q Free Tier
		},
		cmd = { "AmazonQ" },
		enabled = false,
		cond = not_vscode,
	},
	{
		"yetone/avante.nvim",
		version = false,
		build = "make",
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons",
		},
		opts = {
			provider = "gemini",
			providers = {
				claude = {
					api_key_name = "cmd:pass show anthropic.com/juliette.lamarche.xyz@gmail.com/keys/nvim",
				},
				openai = {
					api_key_name = "cmd:pass show openai.com/juliette.lamarche.xyz@gmail.com/keys/nvim",
				},
				gemini = {
					api_key_name = "cmd:pass show google.com/juliette.lamarche.xyz@gmail.com/keys/nvim",
					endpoint = "https://generativelanguage.googleapis.com/v1beta/models",
					-- find new models here: https://aistudio.google.com/prompts/new_chat
					-- model = "gemini-2.0-pro-exp-02-05",
					-- model = "gemini-2.5-pro-preview-03-25",
					model = "gemini-2.5-flash-preview-04-17",
					timeout = 30000, -- Timeout in milliseconds
					temperature = 0,
					max_tokens = 4096,
				},
			},
			web_search_engine = {
				provider = "tavily", -- tavily, serpapi, searchapi, google, kagi, brave, or searxng
				providers = {
					tavily = {
						api_key_name = "cmd:pass show tavily.com/juliette.lamarche.xyz@gmail.com/keys/nvim",
					},
				},
			},
			mappings = {
				ask = ai .. "a",
				edit = ai .. "e",
				refresh = ai .. "r",
			},
		},
		keys = {
			{
				ai .. "a",
				function()
					require("avante.api").ask()
				end,
				mode = { "n", "x" },
				desc = "Avante Ask",
			},
			{
				ai .. "e",
				function()
					require("avante.api").edit()
				end,
				mode = { "n", "x" },
				desc = "Avante Edit",
			},
			{ ai .. "c", "<cmd>AvanteChat<cr>", desc = "Avante Chat" },
			{ ai .. reverse("c"), "<cmd>AvanteChatNew<cr>", desc = "Avante Chat New" },
			{
				ai .. pick,
				function()
					require("avante.api").select_history()
				end,
				desc = "Avante Pick Chat",
			},
			{
				ai .. "x",
				function()
					require("avante.api").stop()
				end,
				desc = "Avante Stop",
			},
			{
				ai .. "s",
				function()
					require("avante.api").get_suggestion()
				end,
				desc = "Avante Suggest",
			},
		},
		cmd = {
			"AvanteModels",
			"AvanteAsk",
			"AvanteChat",
			"AvanteToggle",
			"AvanteEdit",
			"AvanteRefresh",
			"AvanteBuild",
			"AvanteSwitchProvider",
			"AvanteClear",
		},
		enabled = chat == "avante",
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
	{
		"folke/sidekick.nvim",
		dependencies = "zbirenbaum/copilot.lua",
		opts = { nes = { enabled = false } },
		keys = {
			{
				ai_insert.toggle,
				function()
					require("sidekick.cli").toggle({
						name = "claude",
						focus = true,
					})
				end,
				desc = "Sidekick Chat",
			},
			{
				ai .. "a",
				function()
					require("sidekick.cli").prompt()
				end,
				mode = { "n", "x" },
				desc = "Sidekick Ask Prompt",
			},
		},
		enabled = chat == "sidekick",
		cond = not_vscode,
	},
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
			suggestion = completion == "copilot" and {
				auto_trigger = true,
				keymap = {
					accept = ai_insert.accept,
					next = ai_insert.next,
					prev = ai_insert.prev,
				},
			} or nil,
		},
		keys = {
			{
				ai .. "t",
				function()
					require("my.ui_toggle").activate("copilot")
				end,
				desc = "Coplot Toggle Autocomplete",
				mode = { "n", "x" },
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
		"CopilotC-Nvim/CopilotChat.nvim",
		dependencies = {
			{ "zbirenbaum/copilot.lua" },
			{ "nvim-lua/plenary.nvim" },
		},
		opts = {
			prompts = {
				Todo = {
					prompt = "Replace all TODO comments with relevent code",
					description = "Complete the work.",
				},
			},
		},
		keys = {
			{
				ai_insert.accept,
				function()
					require("my.ui_toggle").activate("copilot")
				end,
				desc = "Coplot Chat Open",
				mode = { "n", "x" },
			},
			{
				ai .. "x",
				"<cmd>CopilotChatStop<cr>",
				desc = "Coplot Chat Stop",
			},
			{
				ai .. "r",
				"<cmd>CopilotChatReset<cr>",
				desc = "Coplot Chat Reset",
			},
			{
				ai .. "s",
				"<cmd>CopilotChatSave<cr>",
				desc = "Coplot Chat Save",
			},
			{
				ai .. "l",
				"<cmd>CopilotChatLoad<cr>",
				desc = "Coplot Chat Load",
			},
			{
				ai .. "a",
				function()
					require("my.ui_toggle").activate("copilot", "CopilotChatPrompts")
				end,
				desc = "Coplot Chat Prompts",
				mode = { "n", "x" },
			},
			{
				ai .. "m",
				"<cmd>CopilotChatModels<cr>",
				desc = "Coplot Chat Models",
			},
			{
				ai .. "g",
				"<cmd>CopilotChatAgents<cr>",
				desc = "Coplot Chat Agents",
			},
		},
		enabled = chat == "copilotchat",
		cond = not_vscode,
		cmd = {
			"CopilotChat",
			"CopilotChatOpen",
			"CopilotChatClose",
			"CopilotChatToggle",
			"CopilotChatStop",
			"CopilotChatReset",
			"CopilotChatSave",
			"CopilotChatLoad",
			"CopilotChatPrompts",
			"CopilotChatModels",
			"CopilotChatAgents",
		},
	},
}
