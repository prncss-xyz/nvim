describe("khutulun create", function()
	local original_cmd

	before_each(function()
		original_cmd = vim.cmd
		vim.cmd = { edit = function() end }

		package.loaded["plugins.khutulun.create"] = nil
		package.loaded["plugins.khutulun.snips"] = nil
		package.loaded.luasnip = nil

		local instances = 0
		package.preload["plugins.khutulun.snips"] = function()
			return {
				[".+%.lua"] = function()
					instances = instances + 1
					return { template = "lua module", instance = instances }
				end,
			}
		end
	end)

	after_each(function()
		vim.cmd = original_cmd
		package.preload["plugins.khutulun.snips"] = nil
		package.preload.luasnip = nil
		package.loaded["plugins.khutulun.create"] = nil
		package.loaded["plugins.khutulun.snips"] = nil
		package.loaded.luasnip = nil
	end)

	it("expands a fresh snippet instance for each matching new file", function()
		local expanded = {}
		package.preload.luasnip = function()
			return {
				snippet = function(_, template)
					return { template = template }
				end,
				snip_expand = function(snippet)
					table.insert(expanded, snippet)
				end,
			}
		end

		local create = require("plugins.khutulun.create")
		create.create("first.lua")
		create.create("second.lua")

		assert(#expanded == 2)
		assert(not rawequal(expanded[1], expanded[2]))
		assert(not rawequal(expanded[1].template, expanded[2].template))
	end)
end)
