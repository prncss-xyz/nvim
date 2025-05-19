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

return M
