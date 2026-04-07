local M = {}

function M.current_file_ref()
	return "@" .. vim.fn.expand("%:.")
end

function M.current_line_ref()
	return M.current_file_ref() .. ":L" .. vim.fn.line(".")
end

function M.current_line_content()
	return vim.fn.getline(".")
end

function M.current_position_ref()
	return M.current_line_ref() .. ":C" .. vim.fn.col(".")
end

function M.send_current_position()
	require("plugins.toggleterm.terms").send_lines("agent", { M.current_position_ref() })
end

function M.send_current_file()
	require("plugins.toggleterm.terms").send_lines("agent", { M.current_file_ref() })
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

		local prompt_fn = prompts[choice]
		local prompt_data = prompt_fn()

		require("plugins.toggleterm.terms").send_lines("agent", prompt_data)
	end)
end

return M
