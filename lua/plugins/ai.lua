local not_vscode = require("my.conds").not_vscode
local avante = require("my.conds").avante
local copilot = require("my.conds").copilot
local domain = require("my.parameters").domain
local pick = domain.pick
local ai = domain.ai
local reverse = require("my.parameters").reverse

return {
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
			"AvanteAsk",
			"AvanteChat",
			"AvanteToggle",
			"AvanteEdit",
			"AvanteRefresh",
			"AvanteBuild",
			"AvanteSwitchProvider",
			"AvanteClear",
		},
		enabled = avante,
		cond = not_vscode,
	},
	-- windsurf/codeium,
	{
		"supermaven-inc/supermaven-nvim",
		opts = {
			keymaps = {
				accept_suggestion = "<c-l>",
				clear_suggestion = "<c-c>",
			},
			ignore_filetypes = { markdown = true },
		},
		cmd = {
			"SupermavenUseFree",
			"SupermavenLogout",
			"SupermavenStop",
			"SupermavenStart",
			"SupermavenRestart",
			"SupermavenStatus",
			"SupermavenShowLog",
			"SupermavenClearLog",
			"SupermavenToggle",
		},
		event = "InsertEnter",
		enabled = avante,
		cond = not_vscode,
	},
	{
		"zbirenbaum/copilot.lua",
		opts = {
			suggestion = {
				auto_trigger = true,
				keymap = {
					accept = "<c-l>",
					next = "<c-9>",
					prev = "<c-0>",
					dismiss = "<c-c>",
				},
			},
		},
		cmd = { "Copilot" },
		event = "InsertEnter",
		enabled = copilot,
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
					description = "Complete the work",
				},
			},
		},
		keys = {
			{
				ai .. "a",
				"<cmd>CopilotChatToggle<cr>",
				desc = "Coplot Chat Toggle",
				mode = { "n", "x" },
			},
			{
				ai .. "x",
				"<cmd>CopilotChatStop<cr>",
				desc = "Coplot Chat Stop",
				mode = { "n", "x" },
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
				pick .. "a",
				"<cmd>CopilotChatPrompts<cr>",
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
		enabled = copilot,
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
