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

local function is_in_view(winnr)
	local visible = winnr and vim.api.nvim_win_is_valid(winnr)
	return visible and nvim_has_focus
end

function M.start_idle_detection(term, idle_timeout, send)
	if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
		return
	end

	local handle = nil
	local active = false

	local function clear()
		if handle then
			vim.fn.timer_stop(handle)
			handle = nil
		end
	end

	vim.api.nvim_buf_attach(term.bufnr, false, {
		on_detach = function()
			clear()
			send({ type = "detach" })
		end,
		on_lines = function()
			if not active then
				active = true
				send({
					type = "status",
					value = "active",
					in_view = is_in_view(term.window),
				})
			end
			clear()
			handle = vim.fn.timer_start(idle_timeout, function()
				active = false
				send({
					type = "status",
					value = "idle",
					in_view = is_in_view(term.window),
				})
			end)
		end,
	})

	clear()
end

return M
