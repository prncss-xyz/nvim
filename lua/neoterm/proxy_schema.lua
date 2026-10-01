local M = {}

function M.ensure(source, target)
	local lines = vim.fn.readfile(source)
	assert(#lines > 0, "Varlock agent schema is empty: " .. source)
	local opencode_found = false
	for i, line in ipairs(lines) do
		local key = line:match("^([A-Z_][A-Z0-9_]*)=")
		if key and i > 1 and lines[i - 1]:match("^#.*@sensitive") and not lines[i - 1]:find("@proxy", 1, true) then
			if key == "OPENCODE_API_KEY" then
				lines[i - 1] = lines[i - 1] .. ' @proxy(domain="opencode.ai", path="/zen/**")'
			else
				-- Preserve the behavior of varlock run for keys without a route.
				lines[i - 1] = lines[i - 1] .. " @proxy=passthrough"
			end
		end
		if key == "OPENCODE_API_KEY" then
			opencode_found = true
		end
	end
	assert(opencode_found, "Varlock agent schema has no OPENCODE_API_KEY")
	local content = table.concat(lines, "\n") .. "\n"
	if vim.fn.filereadable(target) == 1 and table.concat(vim.fn.readfile(target), "\n") .. "\n" == content then
		return target
	end
	vim.fn.mkdir(vim.fs.dirname(target), "p", 448)
	local temporary = target .. "." .. vim.fn.getpid() .. ".tmp"
	vim.fn.writefile(lines, temporary)
	vim.uv.fs_chmod(temporary, 384)
	assert(vim.uv.fs_rename(temporary, target), "Could not write Varlock proxy schema: " .. target)
	return target
end

return M
