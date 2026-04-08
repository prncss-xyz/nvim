local M = {}

local global = {}

local Terminal = require("toggleterm.terminal").Terminal
local config = require("plugins.toggleterm.config")

local default_terminal = "term_e"
local last_terminal = nil
local last_by_tag = vim.deepcopy(config.default_by_tag)

local term_cache = {}

local function get_term_conf(cwd, key, o)
	if not o then
		return
	end
	if type(o) == "string" then
		return get_term_conf(cwd, o, config.commands[o])
	end
	if type(o) == "function" then
		return get_term_conf(cwd, key, o())
	end
	return key, type(o) == "table" and o or { cmd = key }
end

local function cache2(p, q, cache, gen)
	cache[p] = cache[p] or {}
	if not cache[p][q] then
		cache[p][q] = gen(p, q)
	end
	return cache[p][q]
end

local function get_term_(cwd, k, background)
	if last_by_tag[k] then
		k = last_by_tag[k]
	end
	local key, o = get_term_conf(cwd, k, config.commands[k])
	if key == nil or o == nil then
		return
	end
	local scope = o.global and global or cwd
	local res = cache2(scope, key, term_cache, function()
		o = vim.deepcopy(o)
		o.display_name = o.display_name or key
		o.on_exit = function()
			term_cache[scope][key] = nil
		end
		if background then
			o.hidden = true
		end
		local term = Terminal:new(o)
		if background then
			term:spawn()
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
	last_terminal = last_terminal or get_term(default_terminal)
	if last_terminal then
		last_terminal:toggle()
	end
end

local function hide_term(terminal)
	if not terminal then
		return
	end
	local winnr = terminal.window
	local is_visible = winnr and vim.api.nvim_win_is_valid(winnr)
	if is_visible then
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
	local is_visible = winnr and vim.api.nvim_win_is_valid(winnr)
	if not is_visible then
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
	local choices = vim.tbl_keys(last_by_tag)
	for key, value in pairs(config.commands) do
		if (not vim.tbl_contains(choices, key)) and (type(value) ~= "function" or value()) then
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

function M.setup_start()
	if setup_start_initialized then
		return
	end
	setup_start_initialized = true

	local function setup()
		local cwd = vim.fn.getcwd()
		if seen_cwds[cwd] then
			return
		end
		seen_cwds[cwd] = true
		config.start(function(key)
			get_term_(cwd, key, true)
		end, cwd)
	end

	setup()

	vim.api.nvim_create_autocmd("DirChanged", {
		callback = setup,
	})
end

return M
