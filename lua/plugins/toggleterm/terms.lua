local M = {}

local global = {}

local Terminal = require("toggleterm.terminal").Terminal
local config = require("plugins.toggleterm.config")
local package = require("plugins.toggleterm.package")

local last_terminal = nil
local term_to_key = {}
local term_to_tag = {}

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

local function should_notify(winnr)
	local visible = winnr and vim.api.nvim_win_is_valid(winnr)
	return not (visible and nvim_has_focus)
end

local function get_term_conf(key, o)
	if o == nil then
		o = config.commands[key]
		if o == nil then
			o = require("plugins.toggleterm.package").find(key)
		end
	end
	if type(o) == "function" then
		o = o()
	end
	if not o then
		return
	end
	if type(o) == "string" then
		return { cmd = o }
	end
	if type(o) == "table" then
		return o
	end
	return { cmd = key }
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

local term_cache = {}
local function get_term_cache(scope)
	term_cache[scope] = term_cache[scope] or {}
	return term_cache[scope]
end

local tag_cache = {}
local function get_tag_cache(scope)
	tag_cache[scope] = tag_cache[scope] or {}
	return tag_cache[scope]
end

local function get_term_(cwd, key, background, conf)
	local last
	last = get_tag_cache(cwd)[key] or get_term_cache(cwd)[key]
	if last then
		local tag = term_to_tag[last]
		if last and tag then
			get_tag_cache(cwd)[tag] = last
		end
		return last
	end
	last = get_tag_cache(global)[key] or get_term_cache(global)[key]
	if last then
		local tag = term_to_tag[last]
		if last and tag then
			get_tag_cache(global)[tag] = last
		end
		return last
	end
	local o
	if conf then
		o = conf
	else
		o = get_term_conf(key)
	end
	if o == nil then
		return
	end
	local scope = o.global and global or cwd
	o = vim.deepcopy(o)
	o.display_name = o.display_name or key
	local ref = { term = nil }
	o.on_exit = function()
		term_cache[scope][key] = nil
		if ref.term then
			term_to_key[ref.term] = nil
			term_to_tag[ref.term] = nil
			if idle_state[ref.term] then
				idle_state[ref.term]()
				idle_state[ref.term] = nil
			end
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
	get_term_cache(scope)[key] = term
	term_to_key[term] = key
	if o.tag then
		get_tag_cache(scope)[o.tag] = term
		term_to_tag[term] = o.tag
	end
	return term
end

local function list_term_items()
	local res = {}
	local function collect(scope)
		for key, term in pairs(get_term_cache(scope)) do
			local title = vim.b[term.bufnr] and vim.b[term.bufnr].term_title
				or term.display_name
				or key
			table.insert(res, {
				key = key,
				display_name = title,
			})
		end
	end
	collect(vim.fn.getcwd())
	collect(global)
	table.sort(res, function(a, b)
		return a.key < b.key
	end)
	return res
end

local function get_term(key, background, conf)
	if key == nil then
		return nil
	end
	local cwd = vim.fn.getcwd()
	return get_term_(cwd, key, background, conf)
end

local function pad(s, len)
	if #s >= len then
		return s
	end
	return s .. string.rep(" ", len - #s)
end

function M.select_term()
	vim.ui.select(list_term_items(), {
		prompt = "Select term",
		format_item = function(item)
			local padded = pad(item.key, 20)
			if item.display_name == item.key then
				return padded
			end
			return padded .. "  \u{2014}  " .. item.display_name
		end,
	}, function(item)
		if not item then
			return
		end
		M.focus_term(item.key)
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

local function prepare_term(key, conf)
	local next_terminal = get_term(key, nil, conf)
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

function M.focus_term(key, conf)
	local next_terminal = prepare_term(key, conf)
	if not next_terminal then
		return
	end
	local winnr = next_terminal.window
	if not is_open(winnr) then
		next_terminal:toggle()
	else
		vim.api.nvim_set_current_win(winnr)
	end
	return next_terminal
end

function M.create_term(key, conf)
	local o
	if conf then
		o = conf
	else
		o = get_term_conf(key)
	end
	if o == nil then
		return
	end
	local scope = o.global and global or vim.fn.getcwd()
	local cache = get_term_cache(scope)
	local i = 0
	local key_ = key
	while cache[key_] do
		i = i + 1
		key_ = key .. ":" .. tostring(i)
	end
	M.focus_term(key_, conf)
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

function M.select_command(create)
	local choices = {}
	for key, value in pairs(config.commands) do
		local conf = get_term_conf(key, value)
		if conf then
			table.insert(choices, {
				key = key,
				conf = conf,
			})
		end
	end
	package.add_npm_scripts(choices)
	table.sort(choices, function(a, b)
		return a.key < b.key
	end)
	vim.ui.select(choices, {
		prompt = "Select command: ",
		format_item = function(item)
			return item.key
		end,
	}, function(choice)
		if not choice then
			return
		end
		if create then
			M.create_term(choice.key, choice.conf)
		else
			M.focus_term(choice.key, choice.conf)
		end
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
	-- we want to allow nil inside the array
	for _, key in pairs(config.auto) do
		get_term(key, true)
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

function M.get_last_by_tag(key)
	local last = get_tag_cache(vim.fn.getcwd())[key]
		or get_tag_cache(global)[key]
		or get_term_cache(vim.fn.getcwd())[key]
		or get_term_cache(global)[key]
	if last then
		local is_valid = not last.bufnr or last.bufnr <= 0 or vim.api.nvim_buf_is_valid(last.bufnr)
		if is_valid and term_to_key[last] then
			return term_to_key[last]
		end
	end
	if config.tags_defaults and config.tags_defaults[key] then
		return config.tags_defaults[key]
	end
	return nil
end

return M
