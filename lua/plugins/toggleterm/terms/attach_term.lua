local M = {}

local window = require("plugins.toggleterm.terms.window")
local is_in_view = window.is_in_view
local last_win_ctx = require("plugins.toggleterm.terms.last_win_ctx")

function M.attach_term(term, send)
	if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
		return
	end

	local handle = nil
	local seen = false
	local url_sent = false

	local function clear()
		if handle then
			vim.fn.timer_stop(handle)
			handle = nil
		end
	end

	vim.api.nvim_create_autocmd("TermEnter", {
		buffer = term.bufnr,
		callback = function()
			seen = seen or is_in_view(term.window)
			send({
				type = "focus",
				ctx = last_win_ctx.get_ctx(),
			})
		end,
	})

	vim.api.nvim_buf_attach(term.bufnr, false, {
		on_detach = function()
			send({ type = "detach" })
		end,
		on_lines = function(_, bufnr, _, first_line, _, new_last_line)
			if not url_sent then
				local lines = vim.api.nvim_buf_get_lines(bufnr, first_line, new_last_line, false)
				for _, line in ipairs(lines) do
					local url = line:match("https?://%S+")
					if url then
						url_sent = true
						send({ type = "url", value = url })
						break
					end
				end
			end
		end,
	})

	clear()
end

return M
