local M = {}

local nvim_has_focus = true

vim.api.nvim_create_autocmd("FocusGained", {
	callback = function()
		nvim_has_focus = true
	end,
})

vim.api.nvim_create_autocmd("FocusLost", {
	callback = function()
		nvim_has_focus = false
	end,
})

function M.is_in_view(winnr)
	local visible = winnr and vim.api.nvim_win_is_valid(winnr)
	return visible and nvim_has_focus
end

return M
