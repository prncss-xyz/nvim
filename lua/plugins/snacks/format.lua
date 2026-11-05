local M = {}

function M.keymap(item, picker)
	local ret = {} ---@type snacks.picker.Highlight[]
	---@type vim.api.keyset.get_keymap
	local k = item.item
	local a = Snacks.picker.util.align

	local lhs = Snacks.util.normkey(k.lhs)
	ret[#ret + 1] = { k.mode, "SnacksPickerKeymapMode" }
	ret[#ret + 1] = { " " }
	ret[#ret + 1] = { a(lhs, 7), "SnacksPickerKeymapLhs" }
	ret[#ret + 1] = { " " }
	local icon_nowait = picker.opts.icons.keymaps.nowait

	if k.nowait == 1 then
		ret[#ret + 1] = { icon_nowait, "SnacksPickerKeymapNowait" }
	else
		ret[#ret + 1] = { (" "):rep(vim.api.nvim_strwidth(icon_nowait)) }
	end
	ret[#ret + 1] = { " " }

	if k.buffer and k.buffer > 0 then
		ret[#ret + 1] = { a("buf:" .. k.buffer, 6), "SnacksPickerBufNr" }
	else
		ret[#ret + 1] = { a("", 6) }
	end
	ret[#ret + 1] = { " " }

	ret[#ret + 1] = { a(k.desc or "", 20) }
	return ret
end

return M
