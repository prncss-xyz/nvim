local M = {}

local Terminal = require("toggleterm.terminal").Terminal
local attach_term = require("plugins.toggleterm.terms.attach_term").attach_term
local last_terminal
local window = require("plugins.toggleterm.terms.window")
local is_visible = window.is_visible

local ensure_dir = require("plugins.toggleterm.terms.ensure_dir").ensure_dir
local project_dir = require("my.rooter").project_dir

local function parse_osc(sequence)
	return sequence:match("^\27%](%d+);([^\7\27]*)")
end

local function osc_dir(payload)
	local path = payload:match("^file://[^/]*(/.*)$")
	if not path then
		return nil
	end
	local ok, decoded = pcall(vim.uri_decode, path)
	return ok and decoded or nil
end

local function osc_notification(payload)
	local notification = payload:match("^notify;(.*)$")
	if not notification then
		return nil
	end
	local title, message = notification:match("^([^;]*);(.*)$")
	return title or "", message or notification
end

local shell_phases = {
	A = "prompt",
	B = "input",
	C = "output",
	D = "finished",
}

local function osc_shell(payload)
	local marker, fields = payload:match("^([ABCD]);?(.*)$")
	local phase = shell_phases[marker]
	if not phase then
		return nil
	end
	if marker ~= "D" then
		return phase
	end
	local exit_code = fields:match("^%-?%d+$") and fields
		or fields:match("^exit=(%-?%d+)")
		or fields:match(";exit=(%-?%d+)")
	return phase, exit_code
end

local shutting_down = false

vim.api.nvim_create_autocmd("ExitPre", {
	callback = function()
		shutting_down = true
	end,
})

function M.create_term(opts, send, prepare, min_runtime, notify)
	local opts_ = vim.deepcopy(opts)
	local exit_policy = opts_.on_exit
	local started_at
	local restart_scheduled = false
	local restart_requested = false
	local kill_requested = false
	local reopen_after_restart = false
	local original_on_create = opts_.on_create
	local attached_bufnr
	local reset_status_detection
	local schedule_status_detection
	local osc = { title = "", progress = "", shell_phase = "", shell_exit_code = "" }
	local attachment_generation = 0
	local function attach_status(term)
		if not term.bufnr or term.bufnr <= 0 or term.bufnr == attached_bufnr then
			return
		end
		local replacing = attached_bufnr ~= nil
		attached_bufnr = term.bufnr
		osc.title = ""
		osc.progress = ""
		osc.shell_phase = ""
		osc.shell_exit_code = ""
		attachment_generation = attachment_generation + 1
		local generation = attachment_generation
		vim.api.nvim_create_autocmd("TermRequest", {
			buffer = term.bufnr,
			callback = function(event)
				if generation ~= attachment_generation then
					return
				end
				local command, payload = parse_osc(event.data.sequence)
				if not command then
					return
				end
				if command == "777" then
					local title, message = osc_notification(payload)
					if title then
						notify(title, message)
					end
					return
				end
				if command == "0" or command == "2" then
					osc.title = payload
					send({ type = "title", value = payload })
					if schedule_status_detection then
						schedule_status_detection()
					end
					return
				end
				if command == "9" then
					osc.progress = payload
					if schedule_status_detection then
						schedule_status_detection()
					end
					return
				end
				if command == "133" then
					local phase, exit_code = osc_shell(payload)
					if phase then
						osc.shell_phase = phase
						osc.shell_exit_code = exit_code or ""
						if schedule_status_detection then
							schedule_status_detection()
						end
					end
					return
				end
				if command ~= "7" then
					return
				end
				local dir = osc_dir(payload)
				if not dir then
					return
				end
				local resolved_dir = project_dir(dir)
				opts_.dir = resolved_dir
				send({ type = "dir", value = resolved_dir })
				-- Leave TermRequest so opening a file can trigger BufRead and FileType autocmds.
				vim.schedule(function()
					if generation == attachment_generation and opts_.dir == resolved_dir then
						ensure_dir(resolved_dir)
					end
				end)
			end,
		})
		reset_status_detection, schedule_status_detection = attach_term(term, function(event)
			if generation == attachment_generation then
				send(event)
			end
		end, opts_.screen_manifest, osc)
		if replacing then
			send({ type = "create" })
		end
	end
	opts_.close_on_exit = exit_policy ~= "keep" and exit_policy ~= "restart"
	opts_.env = {
		VMUX_COUNT = opts_.instance_count,
	}
	opts_.dir = opts_.dir or vim.fn.getcwd()
	opts_.on_open = function()
		send({ type = "focus" })
		vim.schedule(function()
			vim.cmd.startinsert()
		end)
	end
	opts_.on_create = function(term)
		started_at = vim.uv.hrtime()
		restart_scheduled = false
		attach_status(term)
		if original_on_create then
			original_on_create(term)
		end
	end

	function opts_.on_exit(term, _, exit_code)
		if shutting_down then
			return
		end
		if restart_requested or kill_requested then
			local should_restart = restart_requested
			restart_requested = false
			kill_requested = false
			vim.schedule(function()
				if term.bufnr and vim.api.nvim_buf_is_valid(term.bufnr) then
					vim.bo[term.bufnr].modified = false
				end
				term:shutdown()
				if should_restart then
					ensure_dir(opts_.dir)
					if reopen_after_restart then
						term:open()
						last_terminal = term
					else
						term:spawn()
					end
				end
			end)
			return
		end
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

	local term = Terminal:new(opts_)
	if prepare then
		term:spawn()
	end
	vim.schedule(function()
		if term and term.bufnr and term.bufnr > 0 then
			ensure_dir(opts_.dir)
			attach_status(term)
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
			ensure_dir(opts_.dir)
		end
		term:toggle()
	end

	local function focus()
		hide_last()
		if not is_visible(term.window) then
			ensure_dir(opts_.dir)
			term:toggle()
			last_terminal = term
		end
	end

	return {
		toggle = toggle,
		focus = focus,
		is_in_view = function()
			return window.is_in_view(term.window)
		end,
		send_str = function(str, start_insert)
			focus()
			vim.schedule(function()
				vim.api.nvim_chan_send(term.job_id, "\27[200~" .. str .. "\27[201~")
				if start_insert then
					vim.schedule(function()
						vim.cmd.startinsert()
					end)
				end
			end)
		end,
		read = function(read_opts, cb)
			if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
				return cb({})
			end
			local line_count = vim.api.nvim_buf_line_count(term.bufnr)
			if read_opts.regex == nil or read_opts.regex == "" then
				local start = math.max(0, line_count - read_opts.len)
				return cb(vim.api.nvim_buf_get_lines(term.bufnr, start, line_count, false))
			end

			local matcher = vim.regex(read_opts.regex)
			local lines = vim.api.nvim_buf_get_lines(term.bufnr, 0, line_count, false)
			local matches = vim.tbl_filter(function(line)
				return matcher:match_str(line) ~= nil
			end, lines)
			local start = math.max(1, #matches - read_opts.len + 1)
			cb(vim.list_slice(matches, start))
		end,
		restart = function()
			if restart_requested or kill_requested then
				return
			end
			if reset_status_detection then
				reset_status_detection()
			end
			send({ type = "status", value = "idle" })
			reopen_after_restart = is_visible(term.window)
			restart_requested = true
			if term.job_id and vim.fn.jobwait({ term.job_id }, 0)[1] == -1 then
				vim.fn.jobstop(term.job_id)
			else
				opts_.on_exit(term, term.job_id, 0)
			end
		end,
		kill = function()
			if kill_requested or restart_requested then
				return
			end
			kill_requested = true
			if term.job_id and vim.fn.jobwait({ term.job_id }, 0)[1] == -1 then
				vim.fn.jobstop(term.job_id)
			else
				opts_.on_exit(term, term.job_id, 0)
			end
		end,
	}
end

return M
