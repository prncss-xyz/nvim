local M = {}

-- in order to preserve lazy loading, this is copied from 'blink.cmp/lua/blink/cmp/sources/lib/init.lua'
local function blink_get_lsp_capabilities(override, include_nvim_defaults)
	return vim.tbl_deep_extend("force", include_nvim_defaults and vim.lsp.protocol.make_client_capabilities() or {}, {
		textDocument = {
			completion = {
				completionItem = {
					snippetSupport = true,
					commitCharactersSupport = false, -- todo:
					documentationFormat = { "markdown", "plaintext" },
					deprecatedSupport = true,
					preselectSupport = false, -- todo:
					tagSupport = { valueSet = { 1 } }, -- deprecated
					insertReplaceSupport = true, -- todo:
					resolveSupport = {
						properties = {
							"documentation",
							"detail",
							"additionalTextEdits",
							"command",
							"data",
							-- todo: support more properties? should test if it improves latency
						},
					},
					insertTextModeSupport = {
						-- todo: support adjustIndentation
						valueSet = { 1 }, -- asIs
					},
					labelDetailsSupport = true,
				},
				completionList = {
					itemDefaults = {
						"commitCharacters",
						"editRange",
						"insertTextFormat",
						"insertTextMode",
						"data",
					},
				},
				contextSupport = true,
				insertTextMode = 1, -- asIs
			},
		},
	}, override or {})
end

M.cmp_capabilities = blink_get_lsp_capabilities({
	textDocument = {
		foldingRange = {
			dynamicRegistration = false,
			lineFoldingOnly = true,
		},
	},
})

return M
