local M = {}

local create_artifact = require("plugins.toggleterm.harness").create_artifact

local function from_contents(contents)
	return function()
		require("plugins.toggleterm.terms").send_str(
			{ tag = "agent" },
			type(contents) == "function" and contents
				or function(ctx)
					return require("plugins.toggleterm.put.position").position(ctx) .. contents
				end
		)
	end
end

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
		input(prompt, cb)
	end
end

local function create_idea(contents)
	create_artifact(contents, "idea.md")
end

local prompts = {
	["Do this: "] = with_prompt("do this"),
	["explain this"] = from_contents("explain this"),
	["curry this"] = from_contents("curry this"),
	["Idea: "] = with_prompt(create_idea),
}

function M.idea()
	prompts["Idea: "](input_for_current_mode(), "Idea: ")
end

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
