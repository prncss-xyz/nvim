local M = {}
local has_lyaml, lyaml = pcall(require, "lyaml")
local mike_farah_yq

local function run_yq(args, input)
	local command = { "yq" }
	vim.list_extend(command, args)
	local result = vim.system(command, { stdin = input, text = true }):wait()
	assert(result.code == 0, result.stderr)
	return result.stdout
end

local function is_mike_farah_yq()
	if mike_farah_yq == nil then
		local result = vim.system({ "yq", "--version" }, { text = true }):wait()
		assert(result.code == 0, result.stderr)
		mike_farah_yq = result.stdout:find("mikefarah", 1, true) ~= nil
	end
	return mike_farah_yq
end

local function decode(text)
	if has_lyaml then
		return lyaml.load(text)
	end
	local args = is_mike_farah_yq() and { "-o=json", "." } or { "." }
	local value = vim.json.decode(run_yq(args, text))
	return value ~= vim.NIL and value or nil
end

local function encode(value)
	if has_lyaml then
		local document = lyaml.dump({ value })
		return assert(document:match("^%-%-%-\n(.-)%.%.%.\n?$"))
	end
	local args = is_mike_farah_yq() and { "-p=json", "-o=yaml", "." } or { "-y", "." }
	return vim.trim(run_yq(args, vim.json.encode(value)))
end

local function frontmatter_lines(lines)
	if lines[1] ~= "---" then
		return nil
	end

	for index = 2, #lines do
		if lines[index] == "---" or lines[index] == "..." then
			return {
				last_line = index,
				text = table.concat(vim.list_slice(lines, 2, index - 1), "\n"),
			}
		end
	end

	error("unterminated YAML frontmatter")
end

local function frontmatter(bufnr)
	return frontmatter_lines(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))
end

function M.read(bufnr)
	local result = frontmatter(bufnr or 0)
	if not result then
		return {}
	end

	return decode(result.text)
end

function M.read_file(path)
	local result = frontmatter_lines(vim.fn.readfile(path))
	if not result then
		return {}
	end
	return decode(result.text)
end

function M.write(bufnr, value)
	assert(type(value) == "table", "Markdown frontmatter must be a YAML mapping")
	bufnr = bufnr or 0
	local current = frontmatter(bufnr)
	local replacement = { "---" }
	vim.list_extend(replacement, vim.split(encode(value), "\n", { plain = true, trimempty = true }))
	table.insert(replacement, "---")

	if current then
		vim.api.nvim_buf_set_lines(bufnr, 0, current.last_line, false, replacement)
	else
		table.insert(replacement, "")
		vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, replacement)
	end
end

return M
