local M = {}

local cachedFn = require("my.functions").cachedFn
local Terminal = require("toggleterm.terminal").Terminal

local filetype_to_key = {
	lua = "lua",
	javascript = "node",
	javascriptreact = "node",
	typescript = "node",
	typescriptreact = "node",
}

local opts = {
	dev = { cmd = "pnpm run dev" },
	current = function()
		return { dir = vim.fn.expand("%:p:h") }
	end,
	diff = {
		cmd = require("my.diff").get_cmd(),
		close_on_exit = false,
	},
}

local last_terminal

function M.toggle_float()
	if last_terminal then
		last_terminal:toggle()
	else
		require("plugins.toggleterm.terms").term("term_e"):toggle()
	end
end

local term_width = 80

function M.on_open(terminal)
	last_terminal = terminal
	if terminal.direction == "vertical" then
		vim.cmd("wincmd L")
		vim.api.nvim_win_set_width(0, term_width)
	end
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
	return scoped(vim.fn.getcwd())(key)
end

local last_term_key

function M.term(key)
	local terminal = get_term(key)
	last_term_key = key
	return terminal
end

function M.last_term()
	if not last_term_key then
		return
	end
	return get_term(last_term_key)
end

function M.toggle_last()
	local terminal = M.last_term()
	if terminal then
		terminal:toggle()
	end
end

function M.from_filetype(lang)
	local key = filetype_to_key[lang]
	if not key then
		print("unknown lang", vim.inspect(lang))
		return
	end
	return key
end

function M.send_str(key, message)
	local terminal = M.term(key)
	if not terminal then
		return
	end
	local winnr = terminal.window
	local is_visible = winnr and vim.api.nvim_win_is_valid(winnr)
	if not is_visible then
		terminal:toggle()
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
	local terminal = M.term(key)
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
