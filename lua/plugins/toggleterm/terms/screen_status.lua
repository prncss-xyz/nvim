local M = {}

local function lines(text)
	return vim.split(text, "\n", { plain = true })
end

local function is_horizontal_rule(line)
	local trimmed = vim.trim(line)
	return #trimmed >= 3 and trimmed:find("[─━═╌╍┄┅┈┉─━]") ~= nil and trimmed:find("[%w%p]") == nil
end

local function join_from(xs, index)
	return table.concat(vim.list_slice(xs, index), "\n")
end

local function bottom_non_empty(text, count)
	local xs = lines(text)
	local found = 0
	for index = #xs, 1, -1 do
		if vim.trim(xs[index]) ~= "" then
			found = found + 1
			if found == count then
				return join_from(xs, index)
			end
		end
	end
	return found > 0 and text or ""
end

local function after_last_horizontal_rule(text)
	local xs = lines(text)
	for index = #xs, 1, -1 do
		if is_horizontal_rule(xs[index]) then
			return join_from(xs, index + 1)
		end
	end
	return text
end

local function prompt_box_body(text)
	local xs = lines(text)
	local borders = {}
	for index = #xs, 1, -1 do
		if is_horizontal_rule(xs[index]) then
			table.insert(borders, index)
			if #borders == 2 then
				return table.concat(vim.list_slice(xs, index + 1, borders[1] - 1), "\n")
			end
		end
	end
	return ""
end

local function region(text, spec)
	if not spec or spec == "whole_recent" then
		return text
	end
	local count = spec:match("^bottom_non_empty_lines%((%d+)%)$")
	if count then
		return bottom_non_empty(text, tonumber(count))
	end
	if spec == "after_last_horizontal_rule" then
		return after_last_horizontal_rule(text)
	end
	if spec == "prompt_box_body" then
		return prompt_box_body(text)
	end
	return ""
end

local function regex_matches(pattern, text)
	local ok, regex = pcall(vim.regex, pattern)
	return ok and regex:match_str(text) ~= nil
end

local function line_regex_matches(pattern, text)
	local ok, regex = pcall(vim.regex, pattern)
	if not ok then
		return false
	end
	return vim.iter(lines(text)):any(function(line)
		return regex:match_str(line) ~= nil
	end)
end

local function gate_matches(gate, text)
	local lower = text:lower()
	if not vim.iter(gate.contains or {}):all(function(needle)
		return lower:find(needle:lower(), 1, true) ~= nil
	end) then
		return false
	end
	if not vim.iter(gate.regex or {}):all(function(pattern)
		return regex_matches(pattern, text)
	end) then
		return false
	end
	if not vim.iter(gate.line_regex or {}):all(function(pattern)
		return line_regex_matches(pattern, text)
	end) then
		return false
	end
	if not vim.iter(gate.all or {}):all(function(nested)
		return gate_matches(nested, text)
	end) then
		return false
	end
	if #(gate.any or {}) > 0 and not vim.iter(gate.any):any(function(nested)
		return gate_matches(nested, text)
	end) then
		return false
	end
	return not vim.iter(gate["not"] or {}):any(function(nested)
		return gate_matches(nested, text)
	end)
end

function M.detect(manifest, screen)
	local match
	for _, rule in ipairs(manifest.rules or {}) do
		if gate_matches(rule, region(screen, rule.region)) and (not match or (rule.priority or 0) > (match.priority or 0)) then
			match = rule
		end
	end
	return match and match.status or manifest.default_status
end

return M
