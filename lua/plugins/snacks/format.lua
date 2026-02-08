local M = {}

-- require("my.parameters").dirs.projects
-- Custom formatter that shows file path relative to projects directory
function M.directory_with_parent(item, picker)
	local ret = {} ---@type snacks.picker.Highlight[]

	if not item.file then
		return ret
	end

	local path = Snacks.picker.util.path(item) or item.file

	-- Add icon if enabled
	if picker.opts.icons.files.enabled ~= false then
		local name, cat = path, (item.dir and "directory" or "file")
		local icon, hl = Snacks.util.icon(name, cat, {
			fallback = picker.opts.icons.files,
		})
		if item.dir and item.open then
			icon = picker.opts.icons.files.dir_open
		end
		icon = Snacks.picker.util.align(icon, picker.opts.formatters.file.icon_width or 2)
		ret[#ret + 1] = { icon, hl, virtual = true }
	end

	local base_hl = item.dir and "SnacksPickerDirectory" or "SnacksPickerFile"
	local dir_hl = "SnacksPickerDir"

	-- Get projects directory and calculate relative path
	local projects_dir = require("my.parameters").dirs.projects
	-- Ensure projects_dir has trailing slash for proper matching
	local projects_dir_normalized = projects_dir:gsub("/$", "") .. "/"

	-- Remove trailing slash from path if present
	local clean_path = path:gsub("/$", "")

	-- Calculate relative path
	local relative_path
	if clean_path:sub(1, #projects_dir_normalized) == projects_dir_normalized then
		-- Path is under projects directory, get relative portion
		relative_path = clean_path:sub(#projects_dir_normalized + 1)
	else
		-- Path is not under projects directory, use full path
		relative_path = clean_path
	end

	-- Display the relative path
	if relative_path == "" then
		-- This is the projects directory itself
		ret[#ret + 1] = { ".", base_hl, field = "file" }
	else
		-- Split path into directory and basename
		local dir, base = relative_path:match("^(.*)/(.+)$")
		if base and dir then
			ret[#ret + 1] = { dir .. "/", dir_hl, field = "file" }
			ret[#ret + 1] = { base, base_hl, field = "file" }
		else
			ret[#ret + 1] = { relative_path, base_hl, field = "file" }
		end
	end

	ret[#ret + 1] = { " " }
	return ret
end

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
