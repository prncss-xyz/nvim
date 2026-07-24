local M = {}

local window = require("plugins.toggleterm.terms.window")
local is_in_view = window.is_in_view
local detect_status = require("plugins.toggleterm.terms.screen_status").detect

local function get_local_url(line)
	local url = vim.fn.matchstr(line, [[\vhttps?://%([\w.-]*localhost|127\.0\.0\.1)%([:/?#]\S*)?%(\s|$)@=]])
	return url ~= "" and url or nil
end

function M.attach_term(term, send, screen_manifest)
	if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
		return
	end

	local handle = nil
	local seen = false
	local url_sent = false
	local last_status = nil

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

	local function update_status(bufnr)
		if not screen_manifest or not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end
		local line_count = vim.api.nvim_buf_line_count(bufnr)
		local screen_lines = screen_manifest.screen_lines
			or (term.window and vim.api.nvim_win_is_valid(term.window) and vim.api.nvim_win_get_height(term.window))
			or vim.o.lines
		local first_line = math.max(0, line_count - screen_lines)
		local screen = table.concat(vim.api.nvim_buf_get_lines(bufnr, first_line, line_count, false), "\n")
		local status = detect_status(screen_manifest, screen)
		if status and status ~= last_status then
			last_status = status
			send({ type = "status", value = status })
		end
	end

	local function schedule_status_update(bufnr)
		if not screen_manifest then
			return
		end
		clear()
		handle = vim.fn.timer_start(screen_manifest.debounce_ms or 100, function()
			handle = nil
			update_status(bufnr)
		end)
	end

	vim.api.nvim_buf_attach(term.bufnr, false, {
		on_detach = function()
			clear()
			send({ type = "detach" })
		end,
		on_lines = function(_, bufnr, _, first_line, _, new_last_line)
			if not url_sent then
				local changed_lines = vim.api.nvim_buf_get_lines(bufnr, first_line, new_last_line, false)
				for _, line in ipairs(changed_lines) do
					local url = get_local_url(line)
					if url then
						url_sent = true
						send({ type = "url", value = url })
						break
					end
				end
			end
			schedule_status_update(bufnr)
		end,
	})

	schedule_status_update(term.bufnr)
end

return M
