-- https://github.com/echasnovski/mini.nvim/blob/009435c6c3653d54bc62997ca6b2e8513bc52cf4/lua/mini/misc.lua#L601

local M = {}

local H = {}

H.fit_to_width = function(text, width)
	local t_width = vim.fn.strchars(text)
	return t_width <= width and text or ("…" .. vim.fn.strcharpart(text, t_width - width + 1, width - 1))
end

--- Zoom in and out of a buffer, making it full screen in a floating window
---
--- This function is useful when working with multiple windows but temporarily
--- needing to zoom into one to see more of the code from that buffer. Call it
--- again (without arguments) to zoom out.
---
---@param buf_id number|nil Buffer identifier (see |bufnr()|) to be zoomed.
---   Default: 0 for current.
---@param config table|nil Optional config for window (as for |nvim_open_win()|).
M.zoom = function(buf_id, config)
	-- Hide
	if H.zoom_winid and vim.api.nvim_win_is_valid(H.zoom_winid) then
		pcall(vim.api.nvim_del_augroup_by_name, "MiniMiscZoom")
		vim.api.nvim_win_close(H.zoom_winid, true)
		H.zoom_winid = nil
		return
	end

	-- Show
	local compute_config = function()
		-- Use precise dimensions for no Command line interactions (better scroll)
		local max_width, max_height = vim.o.columns, vim.o.lines - vim.o.cmdheight
		local default_border = (vim.fn.exists("+winborder") == 1 and vim.o.winborder ~= "") and vim.o.winborder
			or "none"
    --stylua: ignore
    local default_config = {
      relative = 'editor', row = 0, col = 0,
      width = max_width, height = max_height,
      title = ' Zoom ', border = default_border,
    }
		local res = vim.tbl_deep_extend("force", default_config, config or {})

		-- Adjust dimensions to fit border
		local border_offset = (res.border or "none") == "none" and 0 or 2
		res.height = math.min(res.height, max_height - border_offset)
		res.width = math.min(res.width, max_width - border_offset)

		-- Ensure proper title
		if type(res.title) == "string" then
			res.title = H.fit_to_width(res.title, res.width)
		end
		if vim.fn.has("nvim-0.9") == 0 then
			res.title = nil
		end

		return res
	end
	H.zoom_winid = vim.api.nvim_open_win(buf_id or 0, true, compute_config())
	vim.wo[H.zoom_winid].winblend = 0
	vim.cmd("normal! zz")

	-- - Make sure zoom window is adjusting to changes in its hyperparameters
	local gr = vim.api.nvim_create_augroup("MiniMiscZoom", { clear = true })
	local adjust_config = function()
		if not (type(H.zoom_winid) == "number" and vim.api.nvim_win_is_valid(H.zoom_winid)) then
			pcall(vim.api.nvim_del_augroup_by_name, "MiniMiscZoom")
			return
		end
		vim.api.nvim_win_set_config(H.zoom_winid, compute_config())
	end
	vim.api.nvim_create_autocmd("VimResized", { group = gr, callback = adjust_config })
	vim.api.nvim_create_autocmd("OptionSet", { group = gr, pattern = "cmdheight", callback = adjust_config })
end

return M
