local M = {}

function M.load_json_file(path)
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local content = file:read("*a")
	file:close()
	local ok, data = pcall(vim.json.decode, content)
	return ok and data or nil
end

return M
