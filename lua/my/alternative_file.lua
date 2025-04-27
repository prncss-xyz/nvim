local M = {}

-- see also: https://github.com/rgroli/other.nvim

local function get_alternative(patterns, file)
	local is_file = require("khutulun.utils.files").is_file
	local match
	for _, pattern in ipairs(patterns) do
		if file:match(pattern[1]) then
			local target = file:gsub(pattern[1], pattern[2])
			if is_file(target) then
				return target, true
			end
			match = match or target
		end
	end
	return match, false
end

function M.alternative(opts)
	local target, doesExists = get_alternative(opts.patterns, vim.fn.expand("%"))
	if doesExists then
		vim.cmd.edit(target)
		return
	end
	if opts.create then
		if opts.cb then
			opts.cb(target)
		else
			vim.cmd.edit(target)
		end
	end
end

return M
