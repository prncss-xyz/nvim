local M = {}

local filetype_to_key = {
	lua = "lua",
	javascript = "node",
	javascriptreact = "node",
	typescript = "node",
	typescriptreact = "node",
}

function M.from_filetype(lang)
	local key = filetype_to_key[lang]
	if not key then
		print("unknown lang", vim.inspect(lang))
		return
	end
	return key
end

function M.toggle(lang)
	local key = M.from_filetype(lang)
	if not key then
		return
	end
	require("plugins.toggleterm.terms").toggle_terminal(key)
end

function M.with(lang, cb)
	local key = M.from_filetype(lang)
	if not key then
		return
	end
	cb()
end
