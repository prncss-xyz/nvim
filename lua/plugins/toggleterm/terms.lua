local M = {}

local global = vim.env.HOME

local Terminal = require("toggleterm.terminal").Terminal
local config = require("plugins.toggleterm.config")

local last_terminal = nil
local last_by_tag = {}

local term_cache = {}
local idle_state = {}

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

local function is_open(winnr)
	return winnr and vim.api.nvim_win_is_valid(winnr)
end

local function is_visible(winnr)
	return winnr and vim.api.nvim_win_is_valid(winnr) and vim.api.nvim_get_current_win() == winnr
end

local function should_notify(winnr)
	local visible = winnr and vim.api.nvim_win_is_valid(winnr)
	return not (visible and nvim_has_focus)
end

local function get_term_conf0(cwd, key, o)
	if not o then
		return nil
	end
	if type(o) == "string" then
		return get_term_conf0(cwd, o, config.commands[o])
	end
	if type(o) == "function" then
		return get_term_conf0(cwd, key, o())
	end
	return key, type(o) == "table" and o or { cmd = key }
end

local function get_term_conf(cwd, key)
	return get_term_conf0(cwd, key, config.commands[key])
end

local function cache2(p, q, cache, gen)
	cache[p] = cache[p] or {}
	if not cache[p][q] then
		cache[p][q] = gen(p, q)
	end
	return cache[p][q]
end

local function start_idle_detection(term, scope, key)
	if not term.bufnr or not vim.api.nvim_buf_is_valid(term.bufnr) then
		return function() end
	end

	local handle = nil

	local function clear()
		if handle then
			vim.fn.timer_stop(handle)
		end
	end

	vim.api.nvim_buf_attach(term.bufnr, false, {
		on_lines = function()
			clear()
			if should_notify(term.window) then
				handle = vim.fn.timer_start(config.idle_timeout, function()
					if should_notify(term.window) then
						config.on_idle(scope, key)
					end
				end)
			end
		end,
	})

	return clear()
end

local function get_term_(cwd, k, background)
	if last_by_tag[k] then
		k = last_by_tag[k]
	end
	local key, o = get_term_conf(cwd, k)
	if key == nil or o == nil then
		return
	end
	local scope = o.global and global or cwd
	local res = cache2(scope, key, term_cache, function()
		o = vim.deepcopy(o)
		o.display_name = o.display_name or key
		local ref = { term = nil }
		o.on_exit = function()
			term_cache[scope][key] = nil
			if ref.term and idle_state[ref.term] then
				idle_state[ref.term]()
				idle_state[ref.term] = nil
			end
		end
		if background then
			o.hidden = true
		end
		local term = Terminal:new(o)
		ref.term = term
		if background then
			term:spawn()
			idle_state[term] = start_idle_detection(term, scope, key)
		else
			vim.schedule(function()
				if term and term.bufnr and term.bufnr > 0 then
					idle_state[term] = start_idle_detection(term, scope, key)
				end
			end)
		end
		return term
	end)
	if o.tag then
		last_by_tag[o.tag] = k
	end
	return res
end

local function list_terms()
	local cwd = vim.fn.getcwd()
	local res = vim.tbl_keys(term_cache[cwd] or {})
	vim.list_extend(res, vim.tbl_keys(term_cache[global] or {}))
	return res
end

local function get_term(key, background)
	if key == nil then
		return nil
	end
	local cwd = vim.fn.getcwd()
	return get_term_(cwd, key, background)
end

function M.select_term()
	vim.ui.select(list_terms(), {
		prompt = "Select term",
	}, function(key)
		if not key then
			return
		end
		M.focus_term(key)
	end)
end

function M.toggle_last_term()
	last_terminal = last_terminal or get_term(config.default_terminal)
	if last_terminal then
		last_terminal:toggle()
	end
end

local function hide_term(terminal)
	if not terminal then
		return
	end
	local winnr = terminal.window
	if is_open(winnr) then
		terminal:toggle()
	end
end

local function prepare_term(key)
	local next_terminal = get_term(key)
	if last_terminal ~= next_terminal then
		hide_term(last_terminal)
		last_terminal = next_terminal
	end
	return next_terminal
end

function M.toggle_term(key)
	local next_terminal = prepare_term(key)
	if next_terminal then
		next_terminal:toggle()
	end
end

function M.focus_term(key)
	local next_terminal = prepare_term(key)
	if not next_terminal then
		return
	end
	local winnr = next_terminal.window
	if not is_visible(winnr) then
		next_terminal:toggle()
	else
		vim.api.nvim_set_current_win(winnr)
	end
	return next_terminal
end

function M.send_str(key, message)
	local terminal = M.focus_term(key)
	if not terminal then
		return
	end
	local job_id = terminal.job_id
	vim.schedule(function()
		vim.api.nvim_chan_send(job_id, message)
	end)
end

function M.send_lines(key, contents)
	local message = ""
	for _, line in ipairs(contents) do
		message = message .. line .. "\n"
	end
	M.send_str(key, message)
	if contents.cr then
		M.send_cr(key)
	end
end

function M.send_cr(key)
	M.send_str(key, string.char(13))
end

function M.interrupt(key)
	M.send_str(key, string.char(03))
end

function M.clear(key)
	M.send_str(key, string.char(12))
end

function M.stop(key)
	local terminal = M.focus_term(key)
	if not terminal then
		return
	end
	local job_id = terminal.job_id
	if not job_id then
		return
	end
	vim.fn.jobstop(job_id)
end

function M.select_command()
	local cwd = vim.fn.getcwd()
	local choices = vim.tbl_keys(last_by_tag)
	for key, value in pairs(config.commands) do
		local _, o = get_term_conf0(cwd, key, value)
		if o then
			table.insert(choices, key)
		end
	end

	vim.ui.select(choices, {
		prompt = "Select command: ",
	}, function(choice)
		if not choice then
			return
		end
		M.focus_term(choice)
	end)
end

local seen_cwds = {}
local setup_start_initialized = false

local function setup()
	local cwd = vim.fn.getcwd()
	if seen_cwds[cwd] then
		return
	end
	seen_cwds[cwd] = true
	for key, value in pairs(config.commands) do
		local _, o = get_term_conf0(cwd, key, value)
		if o and o.auto then
			get_term_(cwd, key, true)
		end
	end
end

function M.setup_start()
	if setup_start_initialized then
		return
	end
	setup_start_initialized = true

	setup()

	vim.api.nvim_create_autocmd("DirChanged", {
		callback = setup,
	})
end

return M
