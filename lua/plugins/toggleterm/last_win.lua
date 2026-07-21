local M = {}

function M.put_last_file_name()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return string.format("@%s ", ctx.path)
	end)
end

function M.put_last_file_line()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return string.format("@%s :L%i ", ctx.path, ctx.row)
	end)
end

function M.put_last_file_pos()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return string.format("@%s :L%iC:%i ", ctx.path, ctx.row, ctx.col)
	end)
end

function M.put_diagnostics(scope)
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return "fix these diagnostics\n" .. require("plugins.toggleterm.diagnostics").get_diagnostics(ctx.bufnr, scope)
	end)
end

function M.get_selection(bufnr)
	-- exit visual/select mode in the target buffer so marks are set
	if vim.api.nvim_get_current_buf() == bufnr and vim.fn.mode():match("[vV\22sS\19]") then
		vim.cmd([[noautocmd normal! \<Esc>]])
	end

	local start = vim.api.nvim_buf_get_mark(bufnr, "<")
	local end_ = vim.api.nvim_buf_get_mark(bufnr, ">")
	local start_row, start_col = start[1] - 1, start[2]
	local end_row, end_col = end_[1] - 1, end_[2] + 1

	-- for linewise visual mode, extend end_col to line end
	if vim.fn.visualmode() == "V" then
		end_col = -1
	end

	local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
	local path = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":.")

	local res = { string.format("%s L%iC:%i", path, start_row + 1, start_col + 1) }
	vim.list_extend(res, lines)
	-- concatenate lines adding a line break at the end of each
	return table.concat(res, "\n") .. "\n"
end

function M.put_selection_to_term()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return M.get_selection(ctx.bufnr)
	end)
end

function M.prompt()
	local prompts = require("plugins.toggleterm.config").prompts
	local choices = vim.tbl_keys(prompts)
	vim.ui.select(choices, {
		prompt = "Select prompt: ",
	}, function(choice)
		if not choice then
			return
		end

		local contents = prompts[choice]
		require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
			return string.format("@%s L%iC:%i %s\n", ctx.path, ctx.row, ctx.col, contents)
		end)
	end)
end

return M
