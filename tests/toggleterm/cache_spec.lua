local Cache = require("plugins.toggleterm.cache")

describe("cache", function()
	it("stores and retrieves nested values", function()
		local cache = Cache.create_cache(2)

		cache.set("terminal", "enabled", false)
		cache.set("terminal", "name", "shell")

		assert.same(false, cache.get("terminal", "enabled"))
		assert.same("shell", cache.get("terminal", "name"))
		assert.same(nil, cache.get("terminal", "missing"))
	end)

	it("visits every cached value", function()
		local cache = Cache.create_cache(2)
		local entries = {}

		cache.set("one", "a", 1)
		cache.set("two", "b", 2)
		cache.each(function(entry)
			entries[entry[1] .. "." .. entry[2]] = entry[3]
		end)

		assert.same({ ["one.a"] = 1, ["two.b"] = 2 }, entries)
	end)
end)
