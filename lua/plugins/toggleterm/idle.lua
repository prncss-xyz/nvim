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

local function should_notify(winnr)
	local visible = winnr and vim.api.nvim_win_is_valid(winnr)
	return not (visible and nvim_has_focus)
end

function M.start_idle_detection(term, idle_timeout, on_idle)
	if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
		return function() end
	end

	local handle = nil

	local function clear()
		if handle then
			vim.fn.timer_stop(handle)
		end
	end

	vim.api.nvim_buf_attach(term.bufnr, false, {
		on_lines = function()
			clear()
			if should_notify(term.window) then
				handle = vim.fn.timer_start(idle_timeout, function()
					if should_notify(term.window) then
						on_idle()
					end
				end)
			end
		end,
	})

	return clear()
end

return M
