local M = {}

local function input_for_current_mode()
	local mode = vim.fn.mode()
	local selection
	if mode:match("[vV\22]") then
		selection = table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = mode }), "\n")
		if vim.trim(selection) == "" then
			selection = nil
		end
	end

	return function(prompt, continuation)
		if selection then
			continuation(selection)
			return
		end
		vim.ui.input({ prompt = prompt }, function(input)
			if input ~= nil and vim.trim(input) ~= "" then
				continuation(input)
			end
		end)
	end
end

local function with_prompt(cb)
	return function(input, prompt)
		input(prompt, function(contents)
			cb(contents, prompt)
		end)
	end
end

local function create_artifact(filename)
	return with_prompt(function(contents)
		require("plugins.toggleterm.harness").create_artifact(contents, filename)
	end)
end

local function sender(prefix)
	return with_prompt(function(contents, prompt)
		require("plugins.toggleterm.terms").send_str({ tag = "agent" }, (prefix or prompt) .. " " .. contents)
	end)
end

local function send_with_pos(_, prompt)
	require("plugins.toggleterm.terms").send_str({ tag = "agent" }, function(ctx)
		return prompt .. ": " .. require("plugins.toggleterm.put.position").position(ctx)
	end)
end

local prompts = {
	["do this"] = send_with_pos,
	["explain this"] = send_with_pos,
	["curry this"] = send_with_pos(),
	["where in the codebase "] = sender(),
	["idea"] = create_artifact("idea.md"),
}

function M.prompt()
	local input = input_for_current_mode()
	local choices = vim.tbl_keys(prompts)
	vim.ui.select(choices, {
		prompt = "Select prompt: ",
	}, function(choice)
		if not choice then
			return
		end
		local contents = prompts[choice]
		if not contents then
			return
		end
		vim.schedule(function()
			contents(input, choice)
		end)
	end)
end

return M
