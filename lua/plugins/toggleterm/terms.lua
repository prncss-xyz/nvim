local M = {}

local cache2 = require("my.functions").cache2
local Terminal = require("toggleterm.terminal").Terminal

local opts = {
	dev = { cmd = "pnpm run dev" },
	current = function()
		return { dir = vim.fn.expand("%:p:h") }
	end,
	term_e = {},
	term_r = {},
	diff = {
		cmd = require("my.diff").get_cmd(),
		close_on_exit = false,
	},
}

local default_terminal = "term_e"
local last_terminal = nil

function M.on_open(terminal)
	last_terminal = terminal
end

local term_cache = {}

local get_term_ = cache2(term_cache, function(scope, key)
	local o = opts[key] or { cmd = key }
	if type(o) == "function" then
		o = o()
	end
	o.display_name = o.display_name or key
	o.on_exit = function()
		term_cache[scope][key] = nil
	end
	return Terminal:new(o)
end)

local function list_terms()
	local scope = vim.fn.getcwd()
	local cache = term_cache[scope] or {}
	return vim.tbl_keys(cache)
end

local function get_term(key)
	if key == nil then
		return nil
	end
	local scope = vim.fn.getcwd()
	return get_term_(scope, key)
end

function M.select_terminal()
	vim.ui.select(list_terms(), {
		prompt = "Select term",
	}, function(key)
		if not key then
			return
		end
		M.show_term(key)
	end)
end

function M.toggle_last()
	last_terminal = last_terminal or get_term(default_terminal)
	if last_terminal then
		last_terminal:toggle()
	end
end

function M.hide_term(terminal)
	if not terminal then
		return
	end
	local winnr = terminal.window
	local is_visible = winnr and vim.api.nvim_win_is_valid(winnr)
	if is_visible then
		terminal:toggle()
	end
	return terminal
end

local function prepare_term(key)
	local next_terminal = get_term(key)
	if not next_terminal then
		return
	end
	if last_terminal and last_terminal ~= next_terminal then
		M.hide_term(last_terminal)
	end
	last_terminal = next_terminal
	return last_terminal
end

function M.toggle_term(key)
	local next_terminal = prepare_term(key)
	if next_terminal then
		next_terminal:toggle()
	end
end

function M.show_term(key)
	local next_terminal = prepare_term(key)
	if not next_terminal then
		return
	end
	local winnr = next_terminal.window
	local is_visible = winnr and vim.api.nvim_win_is_valid(winnr)
	if not is_visible then
		next_terminal:toggle()
	end
	return next_terminal
end

function M.send_str(key, message)
	local terminal = M.show_term(key)
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
		M.cr(key)
	end
end

function M.cr(key)
	M.send_str(key, string.char(13))
end

function M.interrupt(key)
	M.send_str(key, string.char(03))
end

function M.clear(key)
	M.send_str(key, string.char(12))
end

function M.stop(key)
	local terminal = M.show_term(key)
	if not terminal then
		return
	end
	local job_id = terminal.job_id
	if not job_id then
		return
	end
	vim.fn.jobstop(job_id)
end

return M
