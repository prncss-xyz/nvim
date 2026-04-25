local M = {}

function M.current_file()
	return string.format("@%s", vim.fn.expand("%:."))
end
function M.current_line()
	return string.format("@%s :L%d", vim.fn.expand("%:."), vim.fn.line("."))
end

function M.current_position()
	return string.format("@%s :L%d:C%d", vim.fn.expand("%:."), vim.fn.line("."), vim.fn.col("."))
end

function M.send_current_position()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end
	require("plugins.toggleterm.terms").send_lines(key, { M.current_position() })
end

function M.send_current_file()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end
	require("plugins.toggleterm.terms").send_lines(key, { M.current_file() .. " " })
end

function M.prompt()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end
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

		require("plugins.toggleterm.terms").send_lines(key, prompt_data)
	end)
end

function M.new()
	local key = require("plugins.toggleterm.terms").get_last_by_tag("agent")
	if not key then
		return
	end
	local command = require("plugins.toggleterm.config").new[key]
	if not command then
		return
	end
	require("plugins.toggleterm.terms").send_lines(key, {
		cr = "true",
		"/" .. command,
	})
end

return M
