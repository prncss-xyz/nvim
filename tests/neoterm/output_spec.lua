local T = MiniTest.new_set()

T["output reads the requested tail lazily and skips trailing empty rows"] = function()
	local buf = vim.api.nvim_create_buf(false, true)
	local output = require("neoterm.terms.output").reader(buf)
	assert.same(nil, output.last_line())
	assert.same({}, output.lines(10))
	vim.api.nvim_buf_set_lines(buf, 0, -1, true, { "first", "", "last", "", "" })
	assert.same("last", output.last_line())
	assert.same({ "", "last" }, output.lines(2))
	assert.same({ "first", "", "last" }, output.lines(10))
	assert.same({}, output.lines(0))
	assert.same(false, pcall(output.lines, -1))
	assert.same(false, pcall(output.lines, 1.5))
	vim.api.nvim_buf_delete(buf, { force = true })
end

return T
