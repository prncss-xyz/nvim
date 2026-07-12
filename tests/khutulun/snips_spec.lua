describe("khutulun snippets", function()
	local original_luasnip
	local original_fmt

	before_each(function()
		original_luasnip = package.preload.luasnip
		original_fmt = package.preload["luasnip.extras.fmt"]
		package.loaded.luasnip = nil
		package.loaded["luasnip.extras.fmt"] = nil
		package.loaded["plugins.khutulun.snips"] = nil

		package.preload.luasnip = function()
			return {
				insert_node = function(position, default)
					return { type = "insert", position = position, default = default }
				end,
			}
		end
		package.preload["luasnip.extras.fmt"] = function()
			return {
				fmt = function(_, nodes)
					return { { type = "formatted", nodes = nodes } }
				end,
			}
		end
	end)

	after_each(function()
		package.preload.luasnip = original_luasnip
		package.preload["luasnip.extras.fmt"] = original_fmt
		package.loaded.luasnip = nil
		package.loaded["luasnip.extras.fmt"] = nil
		package.loaded["plugins.khutulun.snips"] = nil
	end)

	it("returns a fresh, flat node list", function()
		local factory = require("plugins.khutulun.snips")[".+%.lua"]
		local first = factory()
		local second = factory()

		assert(first[1].type == "formatted")
		assert(not rawequal(first[1], second[1]))
	end)
end)
