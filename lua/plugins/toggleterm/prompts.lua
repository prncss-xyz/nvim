local M = {}

local prompts = {
	todo = function()
		return {
			cr = true,
			"do this",
			require("plugins.toggleterm.agents").current_line_ref(),
			require("plugins.toggleterm.agents").current_line_content(),
		}
	end,
	fixme = function()
		return {
			"fix this",
			require("plugins.toggleterm.agents").current_line_ref(),
			require("plugins.toggleterm.agents").current_line_content(),
		}
	end,
	explain = function()
		return {
			cr = true,
			"explain this",
			require("plugins.toggleterm.agents").current_line_ref(),
			require("plugins.toggleterm.agents").current_line_content(),
		}
	end,
}

function M.prompt()
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
