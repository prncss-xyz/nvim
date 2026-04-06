local M = {}

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
	agent = require("plugins.toggleterm.agents").get_agent,
	repl = require("plugins.toggleterm.repl").get_REPL,
}

local default_terminal = "term_e"
local last_terminal = nil

function M.on_open(terminal)
	last_terminal = terminal
end

local term_cache = {}

local function get_term_(cwd, key, o)
	if type(o) == "string" then
		return get_term_(cwd, o, opts[o])
	end
	if type(o) == "function" then
		return get_term_(cwd, key, o())
	end

	term_cache[cwd] = term_cache[cwd] or {}
	if term_cache[cwd][key] then
		return term_cache[cwd][key]
	end

	o = o or { cmd = key }
	o.display_name = o.display_name or key
	o.on_exit = function()
		term_cache[cwd][key] = nil
	end

	term_cache[cwd][key] = Terminal:new(o)
	return term_cache[cwd][key]
end

local function list_terms()
	local cwd = vim.fn.getcwd()
	local cache = term_cache[cwd] or {}
	return vim.tbl_keys(cache)
end

local function get_term(key)
	if key == nil then
		return nil
	end
	local cwd = vim.fn.getcwd()
	return get_term_(cwd, key, opts[key])
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
