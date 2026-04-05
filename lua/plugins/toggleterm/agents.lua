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

local agents = { "pi", "gemini", "claude" }
local last_agent = "pi"

function M.send_lines(lines)
	require("plugins.toggleterm.terms").send_lines(last_agent, lines)
end

function M.toggle()
	require("plugins.toggleterm.terms").term(last_agent):toggle()
end

function M.send_current_line()
	M.send_lines({ M.current_position_ref() })
end

function M.send_current_file()
	M.send_lines({ M.current_file_ref() })
end

function M.select_agent()
	vim.ui.select(agents, {
		prompt = "Select agent",
		default = last_agent,
	}, function(choice)
		if not choice then
			return
		end

		last_agent = choice
		M.toggle()
	end)
end

return M
