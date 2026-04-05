local group = vim.api.nvim_create_augroup("MyOSC", {})

local function parse_osc_777(sequence)
	if string.sub(sequence, 1, 6) ~= "\x1b]777;" then
		return nil
	end

	local payload = sequence
		:gsub("^\x1b%]777;", "")
		:gsub("\x1b\\$", "")
		:gsub("\x07$", "")

	local command, arg1, arg2 = payload:match("^([^;]+);([^;]*);(.*)$")
	if command then
		return command, arg1, arg2
	end

	command, arg1 = payload:match("^([^;]+);(.*)$")
	if command then
		return command, arg1
	end

	return payload
end

vim.api.nvim_create_autocmd("TermRequest", {
	group = group,
	callback = function(ev)
		local command, arg1, arg2 = parse_osc_777(ev.data.sequence)
		if command ~= "notify" then
			return
		end

		local args = { "notify-send" }
		if arg1 and arg1 ~= "" then
			table.insert(args, arg1)
		end
		if arg2 and arg2 ~= "" then
			table.insert(args, arg2)
		end

		vim.system(args, { detach = true }, function(result)
			if result.code == 0 then
				return
			end

			vim.schedule(function()
				vim.notify(
					("OSC 777 notify-send failed: %s"):format(result.stderr ~= "" and result.stderr or ("exit code " .. result.code)),
					vim.log.levels.WARN
				)
			end)
		end)
	end,
})
