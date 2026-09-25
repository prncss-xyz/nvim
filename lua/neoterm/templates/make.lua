local async = require("neoterm.helpers.term_templates")

return function(opts, callback)
		async.find_up("Makefile", opts.cwd or opts.dir, math.huge, function(makefiles)
			local makefile = makefiles[1]
			if not makefile then
				return callback("No Makefile found")
			end

			local cwd = vim.fs.dirname(makefile)
			vim.system(
				{ "make", "-rRpq" },
				{
					cwd = cwd,
					text = true,
					env = { LANG = "C.UTF-8" },
				},
				vim.schedule_wrap(function(out)
					if out.code ~= 0 and out.code ~= 1 then
						return callback(out.stderr or out.stdout or "Error running 'make'")
					end

					local definitions = {}
					local parsing = false
					local previous = ""
					for line in vim.gsplit(out.stdout or "", "\n") do
						if line:find("# Files") == 1 then
							parsing = true
						elseif line:find("# Finished Make") == 1 then
							break
						elseif parsing and line:match("^[^%.#%s]") and previous:find("# Not a target") ~= 1 then
							local separator = line:find(":")
							if separator then
								local target = line:sub(1, separator - 1)
								table.insert(definitions, {
									name = string.format("make %s", target),
									cmd = { "make", target },
									cwd = cwd,
								})
							end
						end
						previous = line
					end
					callback(definitions)
				end)
			)
		end)
end
