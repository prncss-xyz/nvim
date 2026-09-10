local M = {}

local detect_status = require("plugins.toggleterm.terms.screen_status").detect
local is_in_view = require("plugins.toggleterm.terms.window").is_in_view

local function get_local_url(line)
	local url = vim.fn.matchstr(line, [[\vhttps?://%([\w.-]*localhost|127\.0\.0\.1)%([:/?#]\S*)?%(\s|$)@=]])
	return url ~= "" and url or nil
end

function M.attach_term(term, send, screen_manifest, osc)
	if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
		return
	end

	local handle = nil
	local url_sent = false
	local last_status = nil
	local pending_idle = nil

	local function clear_timer()
		if handle then
			vim.fn.timer_stop(handle)
			handle = nil
		end
	end

	local function clear_pending_idle()
		pending_idle = nil
	end

	local function clear()
		clear_timer()
		clear_pending_idle()
	end

	vim.api.nvim_create_autocmd("TermEnter", {
		buffer = term.bufnr,
		callback = function()
			send({ type = "focus" })
		end,
	})

	local update_status

	local function schedule_update(bufnr, delay)
		if handle then
			return
		end
		handle = vim.fn.timer_start(delay, function()
			handle = nil
			update_status(bufnr)
		end)
	end

	local function publish_status(status)
		last_status = status
		send({
			type = "status",
			value = status,
			visible = is_in_view(term.window) == true,
		})
	end

	update_status = function(bufnr)
		if not screen_manifest or not vim.api.nvim_buf_is_valid(bufnr) then
			clear_pending_idle()
			return
		end
		local line_count = vim.api.nvim_buf_line_count(bufnr)
		local screen_lines = screen_manifest.screen_lines
			or (term.window and vim.api.nvim_win_is_valid(term.window) and vim.api.nvim_win_get_height(term.window))
			or vim.o.lines
		local first_line = math.max(0, line_count - screen_lines)
		local screen = table.concat(vim.api.nvim_buf_get_lines(bufnr, first_line, line_count, false), "\n")
		local output = detect_status(screen_manifest, screen, osc)
		if not output or output.skip_state_update then
			clear_pending_idle()
			return
		end

		local status = output.status
		if not status or status == last_status then
			clear_pending_idle()
			return
		end

		local plain_idle = last_status == "working" and status == "idle" and not output.visible_idle
		if not plain_idle then
			clear_pending_idle()
			publish_status(status)
			return
		end

		local now = vim.uv.hrtime() / 1000000
		local confirmation_ms = screen_manifest.idle_confirmation_ms or 150
		local confirmations = screen_manifest.idle_confirmations or 2
		local cap_ms = screen_manifest.idle_confirmation_cap_ms or 700
		if not pending_idle then
			pending_idle = { started_at = now, confirmations = 0 }
		elseif now - pending_idle.started_at >= cap_ms then
			clear_pending_idle()
			publish_status(status)
			return
		else
			pending_idle.confirmations = pending_idle.confirmations + 1
			if pending_idle.confirmations >= confirmations then
				clear_pending_idle()
				publish_status(status)
				return
			end
		end
		schedule_update(bufnr, confirmation_ms)
	end

	local function schedule_status_update(bufnr)
		if not screen_manifest then
			return
		end
		schedule_update(bufnr, screen_manifest.debounce_ms or 100)
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
	return function()
		clear()
		last_status = nil
	end, function()
		schedule_status_update(term.bufnr)
	end
end

return M
