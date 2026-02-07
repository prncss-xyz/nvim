local M = {}

-- Custom formatter for directories that shows parent directory before directory name
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

	-- For directories, extract parent and show parent/dirname
	if item.dir then
		-- Remove trailing slash if present
		local clean_path = path:gsub("/$", "")

		-- Extract parent directory and directory name
		local parent_path, dirname = clean_path:match("^(.*)/([^/]+)$")

		if parent_path and dirname then
			-- Get just the parent directory name (not full path)
			local parent_name = parent_path:match("([^/]+)$") or parent_path

			ret[#ret + 1] = { parent_name .. "/", dir_hl, field = "file" }
			ret[#ret + 1] = { dirname, base_hl, field = "file" }
		else
			-- No parent, just show the directory name
			ret[#ret + 1] = { clean_path, base_hl, field = "file" }
		end
	else
		-- For files, use standard file formatting
		local dir, base = path:match("^(.*)/(.+)$")
		if base and dir then
			ret[#ret + 1] = { dir .. "/", dir_hl, field = "file" }
			ret[#ret + 1] = { base, base_hl, field = "file" }
		else
			ret[#ret + 1] = { path, base_hl, field = "file" }
		end
	end

	ret[#ret + 1] = { " " }
	return ret
end

-- Pretty keymaps using which-key icons when available
function M.keymap(item, picker)
	local ret = {} ---@type snacks.picker.Highlight[]
	---@type vim.api.keyset.get_keymap
	local k = item.item
	local a = Snacks.picker.util.align

	if package.loaded["which-key"] then
		local Icons = require("which-key.icons")
		local icon, hl = Icons.get({ keymap = k, desc = k.desc })
		if icon then
			ret[#ret + 1] = { a(icon, 3), hl }
		else
			ret[#ret + 1] = { "   " }
		end
	end
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
