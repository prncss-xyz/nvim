local M = {}

function M.command(name)
	return function(state)
		local command = require("neo-tree.sources.filesystem.commands")[name]
		if state.tree then
			return command(state)
		end

		-- The window and its mappings exist before the first tree is rendered.
		local winid = vim.api.nvim_get_current_win()
		local bufnr = vim.api.nvim_get_current_buf()
		local config, fallback = state.config, state.fallback
		local attempts = 0
		local function retry()
			if not vim.api.nvim_win_is_valid(winid) or vim.api.nvim_get_current_win() ~= winid then
				return
			end
			if vim.api.nvim_win_get_buf(winid) ~= bufnr then
				return
			end
			local current = require("neo-tree.sources.manager").get_state_for_window(winid)
			if current and current.name == "filesystem" and current.tree then
				---@cast current neotree.StateWithTree
				current.config, current.fallback = config, fallback
				command(current)
			elseif attempts < 50 then
				attempts = attempts + 1
				vim.defer_fn(retry, 20)
			else
				vim.notify("Neo-tree is still loading. Try filtering again.", vim.log.levels.INFO)
			end
		end
		vim.schedule(retry)
	end
end

return M
