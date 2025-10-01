local M = {}

local dir = vim.fn.stdpath("data") .. "/targets"

local function get_filepath()
	local cwd = vim.fn.getcwd()
	local escaped = cwd:gsub("([^%w])", function(c)
		return string.format("%%%02X", string.byte(c))
	end)
	return dir .. "/" .. escaped .. ".json"
end

local function read()
	local filepath = get_filepath()
	local f = io.open(filepath, "r")
	if f then
		local content = f:read("*a")
		f:close()
		local ok, data = pcall(vim.json.decode, content)
		if ok then
			return data
		end
	end
	return {}
end

local function write(data)
	vim.fn.mkdir(vim.fn.expand(dir), "p")
	local filepath = get_filepath()
	local f = io.open(filepath, "w")
	if f then
		f:write(vim.json.encode(data, { pretty = false }))
		f:close()
	end
end

function M.register(id)
	local data = read()
	local current = vim.fn.expand("%:p")
	data[id] = current
	write(data)
end

function M.recover(id)
	local data = read()
	local current = data[id]
	if not current then
		return
	end
	if vim.fn.filereadable(current) == 0 then
		return
	end
	vim.cmd.edit(current)
end

return M
