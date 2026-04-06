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

local agents = {
	"pi",
	"gemini",
	"claude",
	"opencode",
	"pi --no-extensions --no-skills --no-prompt-templates --no-themes --no-session",
}
local default_agent = "pi"

local agents_by_cwd = {}

function M.get_agent()
	return agents_by_cwd[vim.fn.getcwd()] or default_agent
end

function M.send_current_position()
	require("plugins.toggleterm.terms").send_lines("agent", { M.current_position_ref() })
end

function M.send_current_file()
	require("plugins.toggleterm.terms").send_lines("agent", { M.current_file_ref() })
end

function M.select_agent()
	vim.ui.select(agents, {
		prompt = "Select agent",
		default = M.get_agent(),
	}, function(choice)
		if not choice then
			return
		end

		agents_by_cwd[vim.fn.getcwd()] = choice
		require("plugins.toggleterm.terms").focus_term("agent")
	end)
end

return M
