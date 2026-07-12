local M = {}

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
				})
			end
			clear()
			handle = vim.fn.timer_start(idle_timeout, function()
				active = false
				send({
					type = "status",
					value = "idle",
				})
			end)
		end,
	})

	clear()
end

return M
