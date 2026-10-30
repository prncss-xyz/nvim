return function(prompt, callback)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.api.nvim_buf_set_name(buf, "neoterm://scratch/" .. buf)
	local width = math.floor(vim.o.columns * 0.6)
	local height = math.floor(vim.o.lines * 0.4)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		style = "minimal",
		border = "single",
		title = " " .. (prompt or "Task") .. " ",
		title_pos = "center",
		footer = " Ctrl-Enter submit · Esc (normal) cancel ",
		footer_pos = "center",
	})
	local function close()
		if vim.api.nvim_buf_is_valid(buf) then
			vim.bo[buf].modified = false
		end
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	local submitted = false
	local function submit()
		if submitted then
			return
		end
		submitted = true
		vim.cmd.stopinsert()
		local contents = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		vim.bo[buf].modified = false
		vim.schedule(function()
			close()
			callback(contents)
		end)
	end
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		once = true,
		callback = submit,
	})
	vim.keymap.set({ "n", "i", "v", "s", "o", "c" }, "<C-CR>", submit, { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true, nowait = true })
	vim.keymap.set("n", "q", close, { buffer = buf, silent = true, nowait = true })
	vim.schedule(function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_set_current_win(win)
			vim.cmd.startinsert()
		end
	end)
end
