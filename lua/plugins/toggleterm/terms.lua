local M = {}

local cachedFn = require("my.functions").cachedFn
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

local scoped = cachedFn(function()
	return cachedFn(function(key, remove)
		local o = opts[key] or { cmd = key }
		if type(o) == "function" then
			o = o()
		end
		o.display_name = o.display_name or key
		o.on_exit = remove
		return Terminal:new(o)
	end)
end)

local function get_term(key)
	if not key then
		return nil
	end
	return scoped(vim.fn.getcwd())(key)
end

function M.toggle_last()
	last_terminal = last_terminal or get_term(default_terminal)
	if last_terminal then
		last_terminal:toggle()
	end
end

function M.hide_term(key)
	local next_terminal = get_term(key)
	if not next_terminal then
		return
	end
	local winnr = next_terminal.window
	local is_visible = winnr and vim.api.nvim_win_is_valid(winnr)
	if is_visible then
		next_terminal:toggle()
	end
	return next_terminal
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
