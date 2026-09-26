local M = {}

-- Case-insensitive literal words must all occur in the displayed row.
function M.filter_rows(rows, query)
	if query and query ~= "" then
		local words = vim.split(vim.fn.tolower(query), "%s+", { trimempty = true })
		return vim.tbl_filter(function(row)
			local text = vim.fn.tolower(row.text)
			for _, word in ipairs(words) do
				if not text:find(word, 1, true) then
					return false
				end
			end
			return true
		end, rows)
	end
	return rows
end

function M.highlight_filter(panel, namespace)
	if panel.filter == nil then
		return false
	end
	if #panel.rows > 0 then
		panel.filter_index = math.min(panel.filter_index or 1, #panel.rows)
		vim.api.nvim_buf_set_extmark(panel.buf, namespace, panel.filter_index - 1, 0, { line_hl_group = "Visual" })
	end
	return true
end

-- panel owns win, buf, rows and transient filter/filter_index fields.
-- options supplies render(), valid(), same(row, selected), and accept().
function M.open_filter(panel, options)
	local render = options.render
	local original_cursor = vim.api.nvim_win_get_cursor(panel.win)
	local input = vim.api.nvim_create_buf(false, true)
	local width = vim.api.nvim_win_get_width(panel.win)
	local popup = vim.api.nvim_open_win(input, true, {
		relative = "win",
		win = panel.win,
		row = vim.api.nvim_win_get_height(panel.win) - 1,
		col = 0,
		width = width,
		height = 1,
		style = "minimal",
		border = "single",
	})
	vim.bo[input].bufhidden = "wipe"
	vim.wo[popup].winblend = 0
	vim.bo[input].buftype = "prompt"
	vim.fn.prompt_setprompt(input, "")
	local timer = assert(vim.uv.new_timer())
	local pending = false
	local finished = false
	local function apply_filter()
		pending = false
		panel.filter = vim.api.nvim_buf_get_lines(input, -2, -1, false)[1]
		panel.filter_index = 1
		render()
	end
	local function finish(accept)
		if finished then
			return
		end
		finished = true
		timer:stop()
		timer:close()
		if accept and pending and options.valid() then
			apply_filter()
		end
		local selected = panel.rows[panel.filter_index or 1]
		panel.filter = nil
		panel.filter_index = nil
		vim.cmd.stopinsert()
		if vim.api.nvim_win_is_valid(popup) then
			vim.api.nvim_win_close(popup, true)
		end
		if not options.valid() or not vim.api.nvim_win_is_valid(panel.win) then
			return
		end
		vim.api.nvim_set_current_win(panel.win)
		render()
		if accept and selected then
			for line, row in ipairs(panel.rows) do
				if options.same(row, selected) then
					vim.api.nvim_win_set_cursor(panel.win, { line, #(row.text:match("^%s*") or "") })
					options.accept()
					break
				end
			end
		else
			original_cursor[1] = math.min(original_cursor[1], vim.api.nvim_buf_line_count(panel.buf))
			vim.api.nvim_win_set_cursor(panel.win, original_cursor)
		end
	end
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = input,
		once = true,
		callback = function()
			if not finished then
				finished = true
				timer:stop()
				timer:close()
				panel.filter = nil
				panel.filter_index = nil
				vim.schedule(function()
					if options.valid() then
						render()
					end
				end)
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = input,
		callback = function()
			if finished or not options.valid() then
				return
			end
			pending = true
			timer:stop()
			timer:start(
				100,
				0,
				vim.schedule_wrap(function()
					if not finished and options.valid() and vim.api.nvim_buf_is_valid(input) then
						apply_filter()
					end
				end)
			)
		end,
	})
	vim.keymap.set({ "n", "i" }, "<Esc>", function()
		finish(false)
	end, { buffer = input })
	local function move(delta)
		if #panel.rows == 0 then
			return
		end
		panel.filter_index = ((panel.filter_index or 1) - 1 + delta) % #panel.rows + 1
		render()
	end
	local operations = {
		next = function()
			move(1)
		end,
		previous = function()
			move(-1)
		end,
		accept = function()
			finish(true)
		end,
	}
	for binding, operation in pairs(require("neoterm.config").filter.keybindings) do
		vim.keymap.set(
			{ "n", "i" },
			binding,
			assert(operations[operation], "Unknown filter operation: " .. operation),
			{
				buffer = input,
			}
		)
	end
	panel.filter = ""
	panel.filter_index = 1
	render()
	vim.cmd.startinsert()
end

function M.show_help(bindings)
	local keys = vim.tbl_keys(bindings)
	table.sort(keys)
	local width = 0
	for _, key in ipairs(keys) do
		width = math.max(width, vim.fn.strdisplaywidth(key))
	end
	local lines = {}
	for _, key in ipairs(keys) do
		table.insert(lines, key .. string.rep(" ", width - vim.fn.strdisplaywidth(key) + 2) .. bindings[key])
	end
	local content_width = 0
	for _, line in ipairs(lines) do
		content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - #lines) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - content_width) / 2)),
		width = content_width,
		height = #lines,
		style = "minimal",
		border = "single",
	})
	for _, key in ipairs({ "q", "<Esc>", "h" }) do
		vim.keymap.set("n", key, function()
			vim.api.nvim_win_close(win, true)
		end, { buffer = buf, silent = true, nowait = true })
	end
end

-- Operations receive the panel state; help always describes its configured bindings.
function M.bind(panel, bindings, operations)
	local handlers = vim.tbl_extend("force", operations, {
		help = function()
			M.show_help(bindings)
		end,
	})
	for binding, operation in pairs(bindings) do
		local handler = assert(handlers[operation], "Unknown panel operation: " .. operation)
		vim.keymap.set("n", binding, function()
			handler(panel)
		end, { buffer = panel.buf, silent = true, nowait = true })
	end
end

return M
