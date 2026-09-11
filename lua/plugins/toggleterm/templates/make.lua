local function get_makefile(opts)
	return vim.fs.find("Makefile", { upward = true, type = "file", path = opts.dir })[1]
end

return {
	generator = function(opts)
		if vim.fn.executable("make") == 0 then
			return 'Command "make" not found'
		end
		local makefile = get_makefile(opts)
		if not makefile then
			return "No Makefile found"
		end

		local cwd = vim.fs.dirname(makefile)
		local out = vim.system({ "make", "-rRpq" }, {
			cwd = cwd,
			text = true,
			env = { LANG = "C.UTF-8" },
		}):wait()
		if out.code ~= 0 and out.code ~= 1 then
			return out.stderr or out.stdout or "Error running 'make'"
		end

		local definitions = {}
		local parsing = false
		local previous = ""
		for line in vim.gsplit(out.stdout or "", "\n") do
			if line:find("# Files") == 1 then
				parsing = true
			elseif line:find("# Finished Make") == 1 then
				break
			elseif parsing and line:match("^[^%.#%s]") and previous:find("# Not a target") ~= 1 then
				local separator = line:find(":")
				if separator then
					local target = line:sub(1, separator - 1)
					table.insert(definitions, {
						name = string.format("make %s", target),
						builder = function()
							return { cmd = { "make", target }, cwd = cwd }
						end,
					})
				end
			end
			previous = line
		end
		return definitions
	end,
}
