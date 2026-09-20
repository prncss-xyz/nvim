local async = require("neoterm.helpers.term_templates")

local function is_mise_path(name, kind)
	name = name:lower()
	if kind == "file" then
		return name:match("^%.?mise%.toml$") ~= nil
			or name:match("^%.?mise%.local%.toml$") ~= nil
			or name:match("^%.?mise%.%w+%.toml$") ~= nil
			or name:match("^%.?mise%.%w+%.local%.toml$") ~= nil
	end
	return kind == "directory"
		and (name:match("^%.?mise$") ~= nil or name:match("^%.?mise%-tasks$") ~= nil or name == ".config")
end

return {
	generator = function(opts, callback)
		async.find_up_match(opts.cwd or opts.dir, is_mise_path, function(mise_file)
			if not mise_file then
				return callback("No mise file or directory found")
			end

			local cwd = vim.fs.dirname(mise_file)
			vim.system(
				{ "mise", "tasks", "--json" },
				{ cwd = cwd, text = true },
				vim.schedule_wrap(function(out)
					local ok, data = pcall(vim.json.decode, out.stdout or "", { luanil = { object = true } })
					if not ok then
						return callback(data)
					end

					local definitions = {}
					for _, value in pairs(data) do
						local name = value.name
						table.insert(definitions, {
							name = string.format("mise %s", name),
							desc = value.description ~= "" and value.description or nil,
							builder = function()
								return { cmd = { "mise", "run", name }, cwd = cwd }
							end,
						})
					end
					callback(definitions)
				end)
			)
		end)
	end,
}
