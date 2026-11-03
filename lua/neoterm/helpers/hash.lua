local digits = "0123456789abcdefghijklmnopqrstuvwxyz"

--- Encode the first 40 bits of the sha256 of `s` in base 36 (at most 8 characters).
--- @param s string
--- @return string
return function(s)
	local value = assert(tonumber(vim.fn.sha256(s):sub(1, 10), 16))
	local result = {}
	repeat
		local digit = value % 36
		table.insert(result, 1, digits:sub(digit + 1, digit + 1))
		value = math.floor(value / 36)
	until value == 0
	return table.concat(result)
end
