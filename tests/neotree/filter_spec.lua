local child = MiniTest.new_child_neovim()
local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
			child.lua([[
				vim.opt.rtp:prepend(vim.fn.getcwd())
				for _, name in ipairs({ "neo-tree.nvim", "nui.nvim", "plenary.nvim" }) do
					local path = vim.fn.stdpath("data") .. "/lazy/" .. name
					assert(vim.uv.fs_stat(path), "Install " .. name .. " before running this test")
					vim.opt.rtp:prepend(path)
				end
				filter = require("plugins.neotree.filter").command("filter_on_submit")
				manager = require("neo-tree.sources.manager")
				function setup_filter(handler)
					require("neo-tree").setup({
						enable_git_status = false,
						enable_diagnostics = false,
						filesystem = { commands = { filter_on_submit = filter } },
						event_handlers = handler and {{
							event = "neo_tree_window_after_open", handler = handler,
						}} or {},
					})
					require("neo-tree.command").execute({ source = "filesystem" })
				end
			]])
		end,
		post_once = child.stop,
	},
})

T["filter invoked before the first render opens after the tree is ready"] = function()
	child.lua([[
		setup_filter(function(args)
			vim.api.nvim_set_current_win(args.winid)
			local state = manager.get_state("filesystem")
			missing_tree = state.tree == nil
			state.config = {}
			state.commands.filter_on_submit(state)
		end)
		assert(vim.wait(3000, function() return vim.bo.filetype == "neo-tree-popup" end))
	]])
	assert.same(true, child.lua_get("missing_tree"))
	assert.same(true, child.lua_get("manager.get_state('filesystem').tree ~= nil"))
end

T["ready filter commands open immediately"] = function()
	child.lua([[
		setup_filter()
		assert(vim.wait(3000, function() return manager.get_state("filesystem").tree ~= nil end))
		local state = manager.get_state("filesystem")
		state.config = {}
		state.commands.filter_on_submit(state)
		opened_immediately = false
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == "neo-tree-popup" then
				opened_immediately = true
			end
		end
	]])
	assert.same(true, child.lua_get("opened_immediately"))
end

T["deferred filter does not take focus after leaving the tree"] = function()
	child.lua([[
		setup_filter()
		assert(vim.wait(3000, function() return manager.get_state("filesystem").tree ~= nil end))
		filter({ config = {} })
		vim.cmd("wincmd p")
		editor = vim.api.nvim_get_current_win()
		vim.wait(50)
	]])
	assert.same(true, child.lua_get("vim.api.nvim_get_current_win() == editor"))
	assert.same(false, child.lua_get("vim.bo.filetype == 'neo-tree-popup'"))
end

return T
