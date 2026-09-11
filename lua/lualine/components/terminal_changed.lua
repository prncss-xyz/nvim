return function()
	local terms = package.loaded["plugins.toggleterm.terms"]
	if not terms then
		return ""
	end
	local res = ""
	if terms.has_changed() then
		res = res .. "*"
	end
	if terms.has_working() then
		res = res .. "●"
	end
	return res
end
