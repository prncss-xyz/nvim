local M = {}

local repl_opts = {
	direction = "vertical",
}

local function get_repl_opts(key, opts)
	return vim.tbl_extend("force", repl_opts, { cmd = key }, opts or {})
end

M.conf = {
	keys = {
		zsh = get_repl_opts("zsh"),
		node = get_repl_opts("node"),
		lua = get_repl_opts("lua"),
		yaegi = get_repl_opts("yaegi"),
	},
	default_non_float = nil,
}

-- TODO:
-- haskell = {
-- command = function(meta)
-- local file = vim.api.nvim_buf_get_name(meta.current_bufnr)
-- return require('haskell-tools').repl.mk_repl_cmd(file)
-- end,
-- },

local terminals = {}
local last_non_float_terminal
local last_float_terminal

function M.toggle_non_float()
	if last_non_float_terminal then
		last_non_float_terminal:toggle()
	elseif M.conf.default_non_float then
		M.terminal(unpack(M.conf.default_non_float))
	end
end

function M.toggle_float()
	if last_float_terminal then
		last_float_terminal:toggle()
	else
		require("plugins.toggleterm.terms").terms.term_e:toggle()
	end
end

local function get_terminal(key)
	if key == nil then
		return
	end
	local opts = M.conf.keys[key] or {}
	local terminal = terminals[key]
	if not terminal then
		terminal = require("toggleterm.terminal").Terminal:new(opts)
		terminal:spawn()
		terminals[key] = terminal
	end
	return terminal
end

function M.terminal(key)
	get_terminal(key):toggle()
end

function M.send_str(key, message)
	local terminal = get_terminal(key)
	if not terminal then
		return
	end
	local winnr = terminal.window
	local is_visible = winnr and vim.api.nvim_win_is_valid(winnr)
	if not is_visible then
		terminal:toggle()
	end
	local job_id = terminal.job_id
	vim.defer_fn(function()
		vim.api.nvim_chan_send(job_id, message)
	end, 0)
end

function M.send_lines(key, contents)
	local message = ""
	for _, line in ipairs(contents) do
		message = message .. line .. "\n"
	end
	M.send_str(key, message)
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
	local terminal = get_terminal(key)
	if not terminal then
		return
	end
	local job_id = terminal.job_id
	if not job_id then
		return
	end
	vim.fn.jobstop(job_id)
end

-- setup helpers

function M.on_open(terminal)
	if terminal.direction == "float" then
		last_float_terminal = terminal
	else
		last_non_float_terminal = terminal
	end
end

return M
