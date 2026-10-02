local T = MiniTest.new_set()

T["proxy schema routes OpenCode and preserves other key behavior"] = function()
	local root = vim.fn.tempname()
	local source = root .. "/source.env.schema"
	local target = root .. "/state/env.agent.schema"
	vim.fn.mkdir(root, "p")
	local original = {
		"# @plugin(@varlock/pass-plugin@1.0.2)",
		"# ---",
		"# @required @sensitive",
		'OPENCODE_API_KEY=pass("opencode/key")',
		"",
		"# @required @sensitive",
		'GROQ_API_KEY=pass("groq/key")',
	}
	vim.fn.writefile(original, source)
	require("neoterm.proxy_schema").ensure(source, target)
	assert.same(original, vim.fn.readfile(source))
	assert.same({
		"# @plugin(@varlock/pass-plugin@1.0.2)",
		"# ---",
		'# @required @sensitive @proxy(domain="opencode.ai", path="/zen/**")',
		'OPENCODE_API_KEY=pass("opencode/key")',
		"",
		"# @required @sensitive @proxy=passthrough",
		'GROQ_API_KEY=pass("groq/key")',
	}, vim.fn.readfile(target))
	assert.same(target, require("neoterm.proxy_schema").ensure(source, target))
	vim.fn.delete(root, "rf")
end

T["proxy schema accepts schemas without OpenCode"] = function()
	local root = vim.fn.tempname()
	local source = root .. "/source.env.schema"
	local target = root .. "/state/proxy.env.schema"
	vim.fn.mkdir(root, "p")
	vim.fn.writefile({ "# @sensitive", 'OTHER_KEY="value"' }, source)
	require("neoterm.proxy_schema").ensure(source, target)
	assert.same({ "# @sensitive @proxy=passthrough", 'OTHER_KEY="value"' }, vim.fn.readfile(target))
	vim.fn.delete(root, "rf")
end

return T
