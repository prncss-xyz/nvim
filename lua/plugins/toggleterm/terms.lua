local M = {}

local personal = require("my.conds").personal
local cached = require("my.tables").cached
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
	current = function()
		return {
			dir = vim.fn.expand("%:p:h"),
		}
	end,
	diff = {
		cmd = "wdiff  __master.txt __diff.txt",
		close_on_exit = false,
	},
}

M.terms = cached(function(key)
	local o = opts[key] or {}
	if type(o) == "function" then
		o = o()
	end
	o.display_name = o.display_name or key
	return Terminal:new(o)
end)

function M.from_filetype()
	local key = filetype_to_key[vim.bo.filetype]
	return M.terms[key]
end

return M
