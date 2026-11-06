local M = {}

local detect_status = require("neoterm.terms.screen_status").detect
local is_in_view = require("neoterm.terms.window").is_in_view

local url_scan_interval_ms = 250
local url_wrap_margin = 4
local remote_url_limit = 10

local url_pattern = [[\vhttps?://[[:alnum:]_.~:/?#@!$&*+,;=%-]+]]

local function get_urls(line)
	local urls = {}
	local offset = 0
	while offset < #line do
		local match = vim.fn.matchstrpos(line, url_pattern, offset)
		local url, start_col, end_col = match[1], match[2], match[3]
		if url == "" then
			break
		end
		url = url:gsub("[.,;:!?]+$", "")
		if not url:match("^https?://$") then
			table.insert(urls, url)
		end
		offset = math.max(end_col, start_col + 1)
	end
	return urls
end

local function is_local_url(url)
	local host = url:match("^https?://([^/:?#]+)")
	return host == "localhost" or host == "127.0.0.1" or (host ~= nil and vim.endswith(host, ".localhost"))
end

function M.attach_term(term, send, screen_manifest, osc)
	if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
		return
	end

	local handle = nil
	local url_handle = nil
	local url_first_line = nil
	local url_last_line = nil
	local sent_urls = {}
	local remote_url_count = 0
	local last_status = nil
	local pending_idle = nil

	local function scan_urls(bufnr, first_line, new_last_line)
		local line_count = vim.api.nvim_buf_line_count(bufnr)
		local width = term.window and vim.api.nvim_win_is_valid(term.window)
			and vim.api.nvim_win_get_width(term.window) or vim.o.columns
		local offset = math.max(0, math.min(line_count, first_line) - url_wrap_margin)
		local changed_end = math.min(line_count, math.max(new_last_line, first_line + 1))
		local lines = vim.api.nvim_buf_get_lines(bufnr, offset, math.min(line_count, changed_end + url_wrap_margin), false)
		if not table.concat(lines):find("://", 1, true) then
			return
		end
		local function is_full(line)
			return #line >= width and vim.fn.strdisplaywidth(line) >= width
		end
		local start = math.min(#lines, first_line + 1 - offset)
		while start > 1 and is_full(lines[start - 1]) do
			start = start - 1
		end
		local finish = changed_end - offset
		while finish < #lines and is_full(lines[finish]) do
			finish = finish + 1
		end
		local index = start
		while index <= finish do
			local joined = lines[index]
			local last = index
			while last < #lines and is_full(lines[last]) do
				last = last + 1
				joined = joined .. lines[last]
			end
			-- A full final line may still receive the rest of its URL.
			if not is_full(lines[last]) then
				for _, url in ipairs(get_urls(joined)) do
					local is_local = is_local_url(url)
					if not sent_urls[url] and (is_local or remote_url_count < remote_url_limit) then
						sent_urls[url] = true
						if not is_local then
							remote_url_count = remote_url_count + 1
						end
						send({ type = "url", value = url })
					end
				end
			end
			index = last + 1
		end
	end

	local function schedule_url_scan(bufnr, first_line, last_line, new_last_line)
		url_first_line = math.min(url_first_line or first_line, first_line)
		url_last_line = math.max(new_last_line, (url_last_line or last_line) + new_last_line - last_line)
		if url_handle then
			return
		end
		url_handle = vim.fn.timer_start(url_scan_interval_ms, function()
			local first, last = url_first_line, url_last_line
			url_handle, url_first_line, url_last_line = nil, nil, nil
			if vim.api.nvim_buf_is_valid(bufnr) then
				scan_urls(bufnr, first, last)
			end
		end)
	end

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
		if url_handle then
			vim.fn.timer_stop(url_handle)
			url_handle, url_first_line, url_last_line = nil, nil, nil
		end
		clear_pending_idle()
	end

	vim.api.nvim_create_autocmd({ "TermEnter", "WinEnter", "BufEnter" }, {
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
		on_lines = function(_, bufnr, _, first_line, last_line, new_last_line)
			schedule_url_scan(bufnr, first_line, last_line, new_last_line)
			schedule_status_update(bufnr)
		end,
	})

	schedule_status_update(term.bufnr)
	return function()
		clear()
		last_status = nil
		sent_urls = {}
		remote_url_count = 0
	end, function()
		schedule_status_update(term.bufnr)
	end
end

return M
