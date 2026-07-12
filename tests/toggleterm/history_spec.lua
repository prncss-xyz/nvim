local History = require("plugins.toggleterm.history")

describe("history", function()
	it("finds the most recently inserted matching item", function()
		local history = History.create_history("id")
		history.insert({ id = "shell", command = "bash" })
		history.insert({ id = "repl", command = "lua" })

		assert.same({ id = "repl", command = "lua" }, history.find(function()
			return true
		end))
	end)

	it("replaces an item with the same key and makes it the most recent item", function()
		local history = History.create_history("id")
		history.insert({ id = "shell", command = "bash" })
		history.insert({ id = "repl", command = "lua" })
		history.insert({ id = "shell", command = "zsh" })

		assert.same(nil, history.find(function(item)
			return item.command == "bash"
		end))
		assert.same({ id = "shell", command = "zsh" }, history.find(function()
			return true
		end))
	end)

	it("removes items with a matching key and leaves the rest in place", function()
		local history = History.create_history("id")
		history.insert({ id = "shell", command = "bash" })
		history.insert({ id = "repl", command = "lua" })
		history.insert({ id = "scratch", command = "python" })

		history.purge("repl")

		assert.same(nil, history.find(function(item)
			return item.id == "repl"
		end))
		assert.same({ id = "scratch", command = "python" }, history.find(function()
			return true
		end))
		assert.same({ id = "shell", command = "bash" }, history.find(function(item)
			return item.id == "shell"
		end))
	end)
end)
