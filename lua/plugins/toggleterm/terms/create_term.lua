local M = {}

local Terminal = require("toggleterm.terminal").Terminal
local attach_term = require("plugins.toggleterm.terms.attach_term").attach_term
local last_terminal
local window = require("plugins.toggleterm.terms.window")
local is_visible = window.is_visible

local ensure_dir = require("plugins.toggleterm.terms.ensure_dir").ensure_dir

function M.create_term(opts, send, prepare, min_runtime)
	local o = vim.deepcopy(opts)
	local exit_policy = o.on_exit
	local started_at
	local restart_scheduled = false
	local original_on_create = o.on_create
	o.close_on_exit = exit_policy ~= "keep" and exit_policy ~= "restart"
	o.env = {
		VMUX_HASH = o.hash,
	}
	o.dir = o.dir or vim.fn.getcwd()
	o.on_open = function()
		vim.schedule(function()
			vim.cmd.startinsert()
		end)
	end
	o.on_create = function(term)
		started_at = vim.uv.hrtime()
		restart_scheduled = false
		if original_on_create then
			original_on_create(term)
		end
	end

	function o.on_exit(term, _, exit_code)
		send({
			type = "status",
			value = exit_code == 0 and "success" or "failure",
		})
		local runtime = started_at and (vim.uv.hrtime() - started_at) / 1000000 or 0
		if exit_policy ~= "restart" or exit_code == 0 or runtime < (min_runtime or 0) or restart_scheduled then
			return
		end
		restart_scheduled = true
		vim.schedule(function()
			if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
				vim.bo[term.bufnr].modified = false
			end
			term:spawn()
		end)
	end

	local term = Terminal:new(o)
	if prepare then
		term:spawn()
	end
	vim.schedule(function()
		if term and term.bufnr and term.bufnr > 0 then
			ensure_dir(o.dir)
			attach_term(term, send)
		end
	end)

	local function hide_last()
		if last_terminal ~= nil and last_terminal ~= term then
			local winnr = last_terminal.window
			if winnr and vim.api.nvim_win_is_valid(winnr) then
				last_terminal:toggle()
				return true
			end
		end
		last_terminal = nil
		return false
	end

	local function toggle()
		if hide_last() then
			return
		end
		if not is_visible(term.window) then
			last_terminal = term
			ensure_dir(o.dir)
		end
		term:toggle()
	end

	local function focus()
		hide_last()
		if not is_visible(term.window) then
			ensure_dir(o.dir)
			term:toggle()
			last_terminal = term
		end
	end

	return {
		toggle = toggle,
		focus = focus,
		send_str = function(str, start_insert)
			focus()
			vim.schedule(function()
				vim.api.nvim_chan_send(term.job_id, str)
				if start_insert then
					vim.schedule(function()
						vim.cmd.startinsert()
					end)
				end
			end)
		end,
		read = function(opts, cb)
			if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
				return cb({})
			end
			local line_count = vim.api.nvim_buf_line_count(term.bufnr)
			if opts.regex == nil or opts.regex == "" then
				local start = math.max(0, line_count - opts.len)
				return cb(vim.api.nvim_buf_get_lines(term.bufnr, start, line_count, false))
			end

			local matcher = vim.regex(opts.regex)
			local lines = vim.api.nvim_buf_get_lines(term.bufnr, 0, line_count, false)
			local matches = vim.tbl_filter(function(line)
				return matcher:match_str(line) ~= nil
			end, lines)
			local start = math.max(1, #matches - opts.len + 1)
			cb(vim.list_slice(matches, start))
		end,
	}
end

return M
