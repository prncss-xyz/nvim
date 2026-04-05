local M = {}

local personal = require("my.conds").personal
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
	dev = { cmd = personal("pnpm run dev", "yarn run dev local") },
	mocks = { cmd = personal(nil, "yarn shared:mocks") },
	lua = { cmd = "lua" },
	node = { cmd = "node" },
	agent = { cmd = "pi" },
	current = function()
		return { dir = vim.fn.expand("%:p:h") }
	end,
	diff = {
		cmd = require("my.diff").get_cmd(),
		close_on_exit = false,
	},
}

M.term, M.remove_term = cachedFn(function(key)
	local o = opts[key] or {}
	if type(o) == "function" then
		o = o()
	end
	o.display_name = o.display_name or key
	o.on_exit = function()
		M.remove_term(key)
	end

	return Terminal:new(o)
end)

function M.from_filetype()
	local key = filetype_to_key[vim.bo.filetype]
	if not key then
		return
	end
	return M.term(key)
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
