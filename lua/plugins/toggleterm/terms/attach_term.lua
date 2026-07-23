local M = {}

local window = require("plugins.toggleterm.terms.window")
local is_in_view = window.is_in_view

local function get_local_url(line)
	local url = vim.fn.matchstr(line, [[\vhttps?://%([\w.-]*localhost|127\.0\.0\.1)%([:/?#]\S*)?%(\s|$)@=]])
	return url ~= "" and url or nil
end

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
			send({ type = "focus" })
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
					local url = get_local_url(line)
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
