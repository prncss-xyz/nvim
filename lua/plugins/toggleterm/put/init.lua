local M = {}

function M.put_file_name()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, require("plugins.toggleterm.put.position").path)
end

function M.put_file_line()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, require("plugins.toggleterm.put.position").row)
end

function M.put_file_pos()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, require("plugins.toggleterm.put.position").position)
end

function M.put_diagnostics(scope)
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return "fix these diagnostics\n" .. require("plugins.toggleterm.diagnostics").get_diagnostics(ctx, scope)
	end)
end

function M.put_selection()
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return require("plugins.toggleterm.put.selection").get_selection(ctx)
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
			return require("plugins.toggleterm.put.position").position(ctx) .. contents
		end)
	end)
end

return M
