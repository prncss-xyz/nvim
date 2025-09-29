return {
	name = "wdiff",
	builder = function()
		return {
			cmd = { "wdiff" },
			args = { "__master.txt", "__diff.txt" },
			components = { "default" },
			metadata = {},
		}
	end,
}
