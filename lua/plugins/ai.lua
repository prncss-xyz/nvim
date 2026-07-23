local not_vscode = require("my.conds").not_vscode
local ai_insert = require("my.parameters").ai_insert
local ai_config = require("my.parameters").ai_config

local completion = ai_config.completion
local chat = ai_config.chat

local mercury_duet = {
	model = "mercury-2",
	end_point = "https://api.inceptionlabs.ai/v1/chat/completions",
	api_key = "INCEPTION_API_KEY",
	stream = true,
}

local qwen_duet = {
	model = "qwen-3-235b-a22b-instruct-2507",
	end_point = "https://api.cerebras.ai/v1/chat/completions",
	api_key = "CEREBRAS_API_KEY",
	stream = false,
	optional = {
		max_tokens = 8192,
	},
}

local duet_config = ai_config.duet == "qwen" and qwen_duet or mercury_duet

return {
	{
		"cursortab/cursortab.nvim",
		dependencies = {
			{
				"copilotlsp-nvim/copilot-lsp",
				init = function()
					vim.g.copilot_nes_debounce = 500
				end,
			},
		},
		opts = {
			provider = {
				type = "copilot",
			},
			keymaps = {
				accept = ai_insert.accept,
				partial_accept = ai_insert.next,
			},
			behavior = {
				ignore_filetypes = { "markdown", "prompt", "snacks_picker_input", "" },
				ignore_gitignored = true,
			},
			blink = {
				enabled = false,
				ghost_text = true,
			},
		},
		build = "cd server && go build",
		enabled = completion == "cursortab",
		event = { "BufReadPre", "BufNewFile" },
	},
	{
		"milanglacier/minuet-ai.nvim",
		opts = {
			provider = "openai_fim_compatible", -- "openai_fim_compatible" | "codestral",
			provider_options = {
				openai_fim_compatible = {
					model = "mercury-edit-2",
					end_point = "https://api.inceptionlabs.ai/v1/fim/completions",
					api_key = "INCEPTION_API_KEY",
					stream = true,
				},
			},
			virtualtext = {
				auto_trigger_ft = { "*" },
				auto_trigger_ignore_ft = { "markdown", "prompt", "snacks_picker_input", "" },
				keymap = {
					prev = ai_insert.prev,
					next = ai_insert.next,
				},
				show_on_completion_menu = true,
			},
			duet = duet_config,
		},
		keys = completion == "minuet" and {
			{
				ai_insert.nes,
				"<cmd>Minuet duet predict<cr>",
				mode = { "n", "i" },
				desc = "Minuet NES predict",
			},
			{
				ai_insert.accept,
				function()
					local duet = require("minuet.duet").action
					if duet.is_visible() then
						duet.apply()
					else
						require("minuet.virtualtext").action.accept()
					end
				end,
				mode = { "n", "i" },
				desc = "Minuet complete or NES apply",
			},
			{
				ai_insert.clear,
				function()
					require("minuet.virtualtext").action.dismiss()
					require("minuet.duet").action.dismiss()
				end,
				mode = { "n", "i" },
				desc = "Minuet clear or NES dismiss",
			},
		},
		enabled = completion == "minuet",
		-- Load before FileType so Minuet's `virtualtext.auto_trigger_ft` hook is registered in time.
		event = { "BufReadPre", "BufNewFile" },
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
			suggestion = { enabled = completion == "copilot" },
			panel = { enabled = false },
			nes = {
				enabled = completion == "copilot",
				keymap = {
					accept_and_goto = false,
					accept = false,
					dismiss = false,
				},
			},
		},
		keys = completion == "copilot" and {
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
		} or nil,
		cmd = { "Copilot" },
		event = "InsertEnter",
		enabled = completion == "copilot" or chat == "copilotchat",
		cond = not_vscode,
	},
}
