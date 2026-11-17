--- Ask a yes/no question; only an explicit "y" confirms.
--- @param prompt string
--- @param callback fun(confirmed: boolean)
return function(prompt, callback)
	vim.ui.input({ prompt = prompt .. " [y/N]: " }, function(answer)
		callback(answer == "y")
	end)
end
