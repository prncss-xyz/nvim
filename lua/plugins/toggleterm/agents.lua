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
local default_agent = "pi"

local agents_by_cwd = {}

local function get_agent()
	return agents_by_cwd[vim.fn.getcwd()] or default_agent
end

function M.send_lines(lines)
	require("plugins.toggleterm.terms").send_lines(get_agent(), lines)
end

function M.toggle()
	require("plugins.toggleterm.terms").term(get_agent()):toggle()
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
		default = get_agent(),
	}, function(choice)
		if not choice then
			return
		end

		agents_by_cwd[vim.fn.getcwd()] = choice
		M.toggle()
	end)
end

return M
