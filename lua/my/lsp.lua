local M = {}

function M.stop_client()
	vim.ui.select(vim.lsp.get_clients(), {
		prompt = "Stop LSP Client",
		format_item = function(item)
			return item.name
		end,
	}, function(res)
		if not res then
			return
		end
		vim.lsp.stop_client(res.id, true)
	end)
end

function M.display_code_actions()
	M.bufnr = vim.api.nvim_get_current_buf()
	local context = { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
	local params = vim.lsp.util.make_range_params()
	params.context = context
	local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 10000)
	if err then
		print("ERROR: " .. err)
		return
	end
	if not results_lsp or vim.tbl_isempty(results_lsp) then
		print("No results from textDocument/codeAction")
		return
	end
	local commands = {}
	for client_id, response in pairs(results_lsp) do
		if response.result then
			local client = vim.lsp.get_client_by_id(client_id)
			for _, result in pairs(response.result) do
				result.client_name = client and client.name or ""
				table.insert(commands, result)
			end
		end
	end
	dd(commands)
end

return M
