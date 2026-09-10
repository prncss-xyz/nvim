local Term = {}
Term.__index = Term

local Terminal = require("toggleterm.terminal").Terminal
local attach_term = require("plugins.toggleterm.terms.attach_term").attach_term
local last_terminal
local window = require("plugins.toggleterm.terms.window")
local is_visible = window.is_visible

local ensure_dir = require("plugins.toggleterm.terms.ensure_dir").ensure_dir
local project_dir = require("my.rooter").project_dir

local function ensure_dir_without_focus(dir)
	local current_win = vim.api.nvim_get_current_win()
	ensure_dir(dir)
	if vim.api.nvim_win_is_valid(current_win) then
		vim.api.nvim_set_current_win(current_win)
	end
end

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

function Term:new(opts, send, prepare, min_runtime, notify)
	local instance = setmetatable({
		send = send,
		notify = notify,
		exit_policy = opts.on_exit,
		cwd = opts.cwd or vim.fn.getcwd(),
		screen_manifest = opts.screen_manifest,
		min_runtime = min_runtime or 0,
		restart_scheduled = false,
		restart_requested = false,
		kill_requested = false,
		reopen_after_restart = false,
		osc = { title = "", progress = "", shell_phase = "", shell_exit_code = "" },
		attachment_generation = 0,
	}, self)

	instance.terminal = Terminal:new({
		cmd = opts.cmd,
		dir = instance.cwd,
		close_on_exit = instance.exit_policy ~= "keep" and instance.exit_policy ~= "restart",
		env = {
			VMUX_COUNT = opts.instance_count,
		},
		on_open = function()
			instance:on_open()
		end,
		on_create = function(terminal)
			instance:on_create(terminal)
		end,
		on_exit = function(terminal, job_id, exit_code)
			instance:on_exit(terminal, job_id, exit_code)
		end,
	})

	if prepare then
		instance.terminal:spawn()
	end
	vim.schedule(function()
		local terminal = instance.terminal
		if terminal and terminal.bufnr and terminal.bufnr > 0 then
			ensure_dir_without_focus(instance.cwd)
			instance:attach_status(terminal)
		end
	end)

	return instance
end

function Term:on_open()
	self.send({ type = "focus" })
	vim.schedule(function()
		vim.cmd.startinsert()
	end)
end

function Term:on_create(terminal)
	self.started_at = vim.uv.hrtime()
	self.restart_scheduled = false
	self:attach_status(terminal)
end

function Term:handle_osc(generation, sequence)
	if generation ~= self.attachment_generation then
		return
	end
	local command, payload = parse_osc(sequence)
	if not command then
		return
	end
	if command == "777" then
		local title, message = osc_notification(payload)
		if title then
			self.notify(title, message)
		end
		return
	end
	if command == "0" or command == "2" then
		self.osc.title = payload
		self.send({ type = "title", value = payload })
		if self.schedule_status_detection then
			self.schedule_status_detection()
		end
		return
	end
	if command == "9" then
		self.osc.progress = payload
		if self.schedule_status_detection then
			self.schedule_status_detection()
		end
		return
	end
	if command == "133" then
		local phase, exit_code = osc_shell(payload)
		if phase then
			self.osc.shell_phase = phase
			self.osc.shell_exit_code = exit_code or ""
			if self.schedule_status_detection then
				self.schedule_status_detection()
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
	self.cwd = resolved_dir
	self.send({ type = "dir", value = resolved_dir })
	-- Leave TermRequest so opening a file can trigger BufRead and FileType autocmds.
	vim.schedule(function()
		if generation ~= self.attachment_generation or self.cwd ~= resolved_dir then
			return
		end
		ensure_dir_without_focus(resolved_dir)
	end)
end

function Term:attach_status(terminal)
	if not terminal.bufnr or terminal.bufnr <= 0 or terminal.bufnr == self.attached_bufnr then
		return
	end
	local replacing = self.attached_bufnr ~= nil
	self.attached_bufnr = terminal.bufnr
	self.osc.title = ""
	self.osc.progress = ""
	self.osc.shell_phase = ""
	self.osc.shell_exit_code = ""
	self.attachment_generation = self.attachment_generation + 1
	local generation = self.attachment_generation
	vim.api.nvim_create_autocmd("TermRequest", {
		buffer = terminal.bufnr,
		callback = function(event)
			self:handle_osc(generation, event.data.sequence)
		end,
	})
	self.reset_status_detection, self.schedule_status_detection = attach_term(terminal, function(event)
		if generation == self.attachment_generation then
			self.send(event)
		end
	end, self.screen_manifest, self.osc)
	if replacing then
		self.send({ type = "create" })
	end
end

function Term:on_exit(terminal, _, exit_code)
	if shutting_down then
		return
	end
	if self.restart_requested or self.kill_requested then
		local should_restart = self.restart_requested
		self.restart_requested = false
		self.kill_requested = false
		vim.schedule(function()
			if terminal.bufnr and vim.api.nvim_buf_is_valid(terminal.bufnr) then
				vim.bo[terminal.bufnr].modified = false
			end
			terminal:shutdown()
			if should_restart then
				ensure_dir(self.cwd)
				if self.reopen_after_restart then
					terminal:open()
					last_terminal = terminal
				else
					terminal:spawn()
				end
			end
		end)
		return
	end
	self.send({
		type = "status",
		value = exit_code == 0 and "success" or "failure",
	})
	local runtime = self.started_at and (vim.uv.hrtime() - self.started_at) / 1000000 or 0
	if self.exit_policy ~= "restart" or exit_code == 0 or runtime < self.min_runtime or self.restart_scheduled then
		return
	end
	self.restart_scheduled = true
	vim.schedule(function()
		if terminal.bufnr and vim.api.nvim_buf_is_valid(terminal.bufnr) then
			vim.bo[terminal.bufnr].modified = false
		end
		terminal:spawn()
	end)
end

function Term:hide_last()
	if last_terminal ~= nil and last_terminal ~= self.terminal then
		local winnr = last_terminal.window
		if winnr and vim.api.nvim_win_is_valid(winnr) then
			last_terminal:toggle()
			return true
		end
	end
	last_terminal = nil
	return false
end

function Term:toggle()
	if self:hide_last() then
		return
	end
	if not is_visible(self.terminal.window) then
		last_terminal = self.terminal
		ensure_dir(self.cwd)
	end
	self.terminal:toggle()
end

function Term:focus()
	self:hide_last()
	if not is_visible(self.terminal.window) then
		ensure_dir(self.cwd)
		self.terminal:toggle()
		last_terminal = self.terminal
	end
end

function Term:is_in_view()
	return window.is_in_view(self.terminal.window)
end

function Term:put(str, start_insert)
	self:focus()
	vim.schedule(function()
		vim.api.nvim_chan_send(self.terminal.job_id, "\27[200~" .. str .. "\27[201~")
		if start_insert then
			vim.schedule(function()
				vim.cmd.startinsert()
			end)
		end
	end)
end

function Term:read(read_opts, cb)
	local terminal = self.terminal
	if not terminal.bufnr or not vim.api.nvim_buf_is_valid(terminal.bufnr) then
		return cb({})
	end
	local line_count = vim.api.nvim_buf_line_count(terminal.bufnr)
	if read_opts.regex == nil or read_opts.regex == "" then
		local start = math.max(0, line_count - read_opts.len)
		return cb(vim.api.nvim_buf_get_lines(terminal.bufnr, start, line_count, false))
	end

	local matcher = vim.regex(read_opts.regex)
	local lines = vim.api.nvim_buf_get_lines(terminal.bufnr, 0, line_count, false)
	local matches = vim.tbl_filter(function(line)
		return matcher:match_str(line) ~= nil
	end, lines)
	local start = math.max(1, #matches - read_opts.len + 1)
	cb(vim.list_slice(matches, start))
end

function Term:restart()
	if self.restart_requested or self.kill_requested then
		return
	end
	if self.reset_status_detection then
		self.reset_status_detection()
	end
	self.send({ type = "status", value = "idle" })
	self.reopen_after_restart = is_visible(self.terminal.window)
	self.restart_requested = true
	if self.terminal.job_id and vim.fn.jobwait({ self.terminal.job_id }, 0)[1] == -1 then
		vim.fn.jobstop(self.terminal.job_id)
	else
		self:on_exit(self.terminal, self.terminal.job_id, 0)
	end
end

function Term:kill()
	if self.kill_requested or self.restart_requested then
		return
	end
	self.kill_requested = true
	if self.terminal.job_id and vim.fn.jobwait({ self.terminal.job_id }, 0)[1] == -1 then
		vim.fn.jobstop(self.terminal.job_id)
	else
		self:on_exit(self.terminal, self.terminal.job_id, 0)
	end
end

return Term
