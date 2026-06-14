local M = {}

local global = {}

local Terminal = require("toggleterm.terminal").Terminal
local config = require("plugins.toggleterm.config")
local package = require("plugins.toggleterm.package")
local start_idle_detection = require("plugins.toggleterm.idle").start_idle_detection

local last_terminal = nil
local term_to_key = {}
local term_to_tag = {}

local idle_state = {}

local function is_open(winnr)
	return winnr and vim.api.nvim_win_is_valid(winnr)
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

local function get_last_from_tag_cache(scope, tag)
	local list = get_tag_cache(scope)[tag]
	if not list then
		return nil
	end
	for i = #list, 1, -1 do
		local term = list[i]
		if term_to_key[term] then
			return term
		else
			table.remove(list, i)
		end
	end
	return nil
end

local function add_to_tag_cache(scope, tag, term)
	local list = get_tag_cache(scope)[tag] or {}
	get_tag_cache(scope)[tag] = list
	for i = #list, 1, -1 do
		if list[i] == term then
			table.remove(list, i)
		end
	end
	table.insert(list, term)
end

local function get_term_(cwd, key, background, conf)
	local last
	last = get_last_from_tag_cache(cwd, key) or get_term_cache(cwd)[key]
	if last then
		local tag = term_to_tag[last]
		if last and tag then
			add_to_tag_cache(cwd, tag, last)
		end
		return last
	end
	last = get_last_from_tag_cache(global, key) or get_term_cache(global)[key]
	if last then
		local tag = term_to_tag[last]
		if last and tag then
			add_to_tag_cache(global, tag, last)
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
	local original_on_open = o.on_open
	o.on_open = function(term)
		vim.schedule(function()
			vim.cmd("startinsert")
		end)
		if original_on_open then
			original_on_open(term)
		end
	end
	if background then
		o.hidden = true
	end
	local term = Terminal:new(o)
	ref.term = term
	local function on_idle()
		config.on_idle(scope, key)
	end
	if background then
		term:spawn()
		idle_state[term] = start_idle_detection(term, config.idle_timeout, on_idle)
	else
		vim.schedule(function()
			if term and term.bufnr and term.bufnr > 0 then
				idle_state[term] = start_idle_detection(term, config.idle_timeout, on_idle)
			end
		end)
	end
	get_term_cache(scope)[key] = term
	term_to_key[term] = key
	local tag = o.tag or key
	if tag then
		add_to_tag_cache(scope, tag, term)
		term_to_tag[term] = tag
	end
	return term
end

local function list_term_items()
	local res = {}
	local function collect(scope)
		for key, term in pairs(get_term_cache(scope)) do
			local title = vim.b[term.bufnr] and vim.b[term.bufnr].term_title or term.display_name or key
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

local function hide_term(terminal)
	if not terminal then
		return
	end
	local winnr = terminal.window
	if is_open(winnr) then
		terminal:toggle()
	end
end

function M.select_any_term()
	local items = {}
	for scope, cache in pairs(term_cache) do
		local scope_name = (scope == global) and "global" or tostring(scope)
		for key, term in pairs(cache) do
			local title = vim.b[term.bufnr] and vim.b[term.bufnr].term_title or term.display_name or key
			table.insert(items, {
				key = key,
				display_name = title,
				scope = scope_name,
				term = term,
			})
		end
	end
	table.sort(items, function(a, b)
		if a.key ~= b.key then
			return a.key < b.key
		end
		return a.scope < b.scope
	end)

	vim.ui.select(items, {
		prompt = "Select Any term",
		format_item = function(item)
			local key_with_scope = item.key .. " (" .. item.scope .. ")"
			local padded = pad(key_with_scope, 20)
			if item.display_name == item.key then
				return padded
			end
			return padded .. "  \u{2014}  " .. item.display_name
		end,
	}, function(item)
		if not item then
			return
		end
		local term = item.term
		if last_terminal ~= term then
			hide_term(last_terminal)
			last_terminal = term
		end
		local winnr = term.window
		if not is_open(winnr) then
			term:toggle()
		else
			vim.api.nvim_set_current_win(winnr)
		end
	end)
end

function M.toggle_last_term()
	last_terminal = last_terminal or get_term(config.default_terminal)
	if last_terminal then
		local tag = term_to_tag[last_terminal]
		if tag then
			local key = M.get_last_by_tag(tag)
			if key then
				M.toggle_term(key)
				return
			end
		end
		last_terminal:toggle()
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
	local last = get_last_from_tag_cache(vim.fn.getcwd(), key)
		or get_last_from_tag_cache(global, key)
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
