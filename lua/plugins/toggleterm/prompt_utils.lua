local M = {}

function M.with_prompt(cb)
	return function(input, prompt)
		input(prompt, function(contents)
			cb(contents, prompt)
		end)
	end
end

function M.create_artifact(filename)
	return M.with_prompt(function(contents)
		require("plugins.toggleterm.harness").create_artifact(contents, filename)
	end)
end

function M.sender(prefix)
	return M.with_prompt(function(contents, prompt)
		require("plugins.toggleterm.terms").put({ tag = "agent" }, (prefix or prompt) .. " " .. contents)
	end)
end

return M
