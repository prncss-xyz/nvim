--- Replace spaces and punctuation with single dashes, trimming dashes at both ends.
--- @param s string
--- @return string
return function(s)
	return (s:gsub("[%s%p]", "-"):gsub("%-+", "-"):gsub("^%-", ""):gsub("%-$", ""))
end
