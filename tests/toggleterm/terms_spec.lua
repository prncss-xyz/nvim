local child = MiniTest.new_child_neovim()

local T = MiniTest.new_set({
	hooks = {
		pre_case = function()
			child.restart({ "-u", "NONE" })
		end,
		post_once = child.stop,
	},
})

T["screen status events"] = MiniTest.new_set()

T["screen status events"]["notify only for unseen status transitions"] = function()
	child.lua([[local notifications = {}
		local send
		local visible = true
		local item = {
			key = "agent",
			display_name = "agent",
			dir = "/tmp",
		}

		package.loaded["plugins.toggleterm.terms.history"] = {
			create_history = function()
				return {
					insert = function() end,
					find = function() return nil end,
					purge = function() end,
					filter = function() return {} end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			create_term = function(_, callback)
				send = callback
				return {
					focus = function() end,
					is_in_view = function() return visible end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			on_status = function(instance)
				table.insert(notifications, instance.status)
			end,
		}
		package.loaded["plugins.toggleterm.terms.get_query_fn"] = {
			get_query_fn = function() return function() return true end end,
		}
		package.loaded["plugins.toggleterm.terms.utils"] = {
			compose_gt = function() return function() return false end end,
			gt_field = function() return function() return false end end,
			lt_field = function() return function() return false end end,
			max_of = function() return item end,
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return { item } end,
		}
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() return function() return "agent" end end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms").focus({})
		send({ type = "status", value = "working", seen = true })
		local visible_status = item.status
		send({ type = "status", value = "working", seen = false })
		visible = true
		send({ type = "status", value = "blocked", seen = false })
		send({ type = "status", value = "blocked", seen = false })
		visible = false
		send({ type = "status", value = "success", seen = false })
		send({ type = "status", value = "success", seen = false })

		result = {
			visible_status = visible_status,
			status = item.status,
			notifications = notifications,
		}
	]])

	assert.same({
		visible_status = "working",
		status = "success",
		notifications = { "success" },
	}, child.lua_get("result"))
end

T["send_str"] = MiniTest.new_set()

T["send_str"]["leaves the terminal in insert mode"] = function()
	child.lua([[local sent
		local item = { key = "agent", dir = "/tmp" }
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			create_term = function()
				return {
					send_str = function(str, start_insert)
						sent = { str, start_insert }
					end,
					is_in_view = function() return true end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = { autostart = {}, on_status = function() end }
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return { item } end,
		}
		package.loaded["plugins.toggleterm.terms.get_query_fn"] = {
			get_query_fn = function() return function() return true end end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		require("plugins.toggleterm.terms").send_str({ key = "agent", dir = "/tmp" }, "hello")
		result = sent
	]])

	assert.same({ "hello", true }, child.lua_get("result"))
end

T["send_str"]["treats artifact as a project-scoped buffer"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		local project = vim.fs.joinpath(projects, "alpha", "main")
		local artifact = vim.fs.joinpath(artifacts, "alpha", "notes.md")
		local source = vim.fs.joinpath(project, "src.lua")
		vim.fn.mkdir(project, "p")
		vim.fn.mkdir(vim.fs.dirname(artifact), "p")
		vim.fn.writefile({ "source" }, source)
		vim.fn.writefile({ "artifact" }, artifact)
		vim.uv.fs_symlink(artifacts .. "/alpha", project .. "/.artifacts")

		package.loaded["my.parameters"] = { dirs = { projects = projects, artifacts = artifacts } }
		package.loaded["plugins.toggleterm.terms.create_term"] = { create_term = function() end }
		package.loaded["plugins.toggleterm.config"] = { autostart = {}, on_status = function() end }
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() error("artifact must not create a terminal") end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		vim.cmd.edit(vim.fn.fnameescape(artifact))
		vim.cmd.edit(vim.fn.fnameescape(source))
		vim.cmd.edit(vim.fn.fnameescape(artifact))
		local terms = require("plugins.toggleterm.terms")
		terms.focus({ key = "artifact" })
		terms.send_str({ key = "artifact" }, function(ctx)
			return " " .. ctx.path .. ":" .. ctx.row
		end)
		result = vim.fn.readfile(artifact)[1]
		vim.cmd.write()
		result = vim.fn.readfile(artifact)[1]
	]])

	assert.same(" src.lua:1artifact", child.lua_get("result"))
end

T["instance numbers"] = MiniTest.new_set()

T["instance numbers"]["are globally unique and reuse the smallest available number"] = function()
	child.lua([[local created = {}
		local callbacks = {}
		local focused = {}
		local notifications = {}
		vim.notify = function(message, level)
			table.insert(notifications, { message, level })
		end

		package.loaded["plugins.toggleterm.terms.create_term"] = {
			create_term = function(item, callback)
				table.insert(created, { key = item.key, instance_count = item.instance_count })
				callbacks[item.key] = callback
				return {
					focus = function() table.insert(focused, item.key) end,
					is_in_view = function() return false end,
					kill = function() end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			on_status = function() end,
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return {} end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local terms = require("plugins.toggleterm.terms")
		terms.focus({ key = "shell", dir = "/one" })
		terms.focus({ key = "agent", dir = "/two" })
		local next_query = { key = "ignored", dir = "/ignored" }
		vim.keymap.set("n", "<F5>", function()
			terms.focus(next_query)
		end)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("2<F5>5<F5>", true, false, true), "x", false)
		vim.wait(10)
		callbacks.shell({ type = "detach" })
		vim.wait(10)
		next_query = { key = "repl", dir = "/three" }
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<F5>", true, false, true), "x", false)
		vim.keymap.set("n", "<F6>", function()
			terms.start({ key = "shell", dir = "/one" })
		end)
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("2<F6><F6>", true, false, true), "x", false)
		result = { created = created, focused = focused, notifications = notifications }
	]])

	assert.same({
		created = {
			{ key = "shell", instance_count = 1 },
			{ key = "agent", instance_count = 2 },
			{ key = "ignored", instance_count = 5 },
			{ key = "repl", instance_count = 1 },
			{ key = "shell", instance_count = 3 },
		},
		focused = { "shell", "agent", "agent", "ignored", "repl", "shell" },
		notifications = {
			{ "Terminal instance 2 already exists", vim.log.levels.ERROR },
		},
	}, child.lua_get("result"))
end

T["artifact cwd"] = MiniTest.new_set()

T["artifact cwd"]["resolves explicit and default branches without git"] = function()
	child.lua([[root = vim.fn.tempname()
		local projects = vim.fs.joinpath(root, "projects")
		local artifacts = vim.fs.joinpath(root, "artifacts")
		vim.fn.mkdir(vim.fs.joinpath(projects, "alpha", "feature"), "p")
		vim.fn.mkdir(vim.fs.joinpath(projects, "alpha", "main"), "p")
		vim.fn.mkdir(vim.fs.joinpath(projects, "beta"), "p")
		vim.fn.mkdir(vim.fs.joinpath(artifacts, "alpha", "feature"), "p")
		vim.fn.mkdir(vim.fs.joinpath(artifacts, "beta"), "p")

		package.loaded["my.parameters"] = { dirs = { projects = projects, artifacts = artifacts } }
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path
		local resolve = require("plugins.toggleterm.terms.artifact_cwd").resolve
		result = {
			explicit = resolve(vim.fs.joinpath(artifacts, "alpha", "feature", "issue.md")),
			missing_branch = resolve(vim.fs.joinpath(artifacts, "alpha", "missing", "issue.md")),
			default_nested = resolve(vim.fs.joinpath(artifacts, "alpha", "issue.md")),
			default_flat = resolve(vim.fs.joinpath(artifacts, "beta", "issue.md")),
			outside = resolve(vim.fs.joinpath(root, "issue.md")),
		}
	]])

	local root = child.lua_get("root")
	assert.same({
		explicit = vim.fs.joinpath(root, "projects", "alpha", "feature"),
		missing_branch = vim.fs.joinpath(root, "projects", "alpha", "main"),
		default_nested = vim.fs.joinpath(root, "projects", "alpha", "main"),
		default_flat = vim.fs.joinpath(root, "projects", "beta"),
	}, child.lua_get("result"))
end

T["directory queries"] = MiniTest.new_set()

T["directory queries"]["matches HOME exactly"] = function()
	local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn
	local filter = get_query_fn({ dir = vim.env.HOME })

	assert(filter({ dir = vim.env.HOME }))
	assert(not filter({ dir = vim.fs.joinpath(vim.env.HOME, "unrelated") }))
end

T["directory queries"]["matches descendants of other directories"] = function()
	local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn
	local parent = vim.fs.joinpath(vim.env.HOME, "project")
	local filter = get_query_fn({ dir = parent })

	assert(filter({ dir = vim.fs.joinpath(parent, "worktree") }))
end

T["terminal panel integration"] = MiniTest.new_set()

T["terminal panel integration"]["uses ui_toggle and forwards make_item lifecycle changes"] = function()
	child.lua([[local sent
		local listener
		local events = {}
		local activated
		local item = {
			key = "agent",
			display_name = "agent",
			dir = "/tmp",
		}
		local stored = {}

		package.loaded["plugins.toggleterm.terms.history"] = {
			create_history = function()
				return {
					insert = function(value) stored = { value } end,
					find = function(cb) return vim.tbl_filter(cb, stored)[1] end,
					purge = function() stored = {} end,
					filter = function(cb) return vim.tbl_filter(cb, stored) end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.terms.create_term"] = {
			create_term = function(_, callback)
				sent = callback
				return {
					focus = function() callback({ type = "focus" }) end,
					is_in_view = function() return false end,
				}
			end,
		}
		package.loaded["plugins.toggleterm.config"] = {
			autostart = {},
			min_runtime = 0,
			on_status = function() end,
			panel = { width = 24 },
		}
		package.loaded["plugins.toggleterm.terms.get_commands"] = {
			get_commands = function() return { item } end,
		}
		package.loaded["plugins.toggleterm.terms.format_item"] = {
			format_item = function() return function(value) return value.key end end,
		}
		package.loaded["my.ui_toggle"] = {
			activate = function(key, action)
				activated = key
				action()
			end,
		}
		package.loaded["plugins.toggleterm.terms.panel"] = {
			toggle = function(query, history, subscribe)
				listener = subscribe(function(event)
					table.insert(events, event.type)
				end)
				result_items = history.filter(require("plugins.toggleterm.terms.get_query_fn").get_query_fn(query))
			end,
		}
		package.path = vim.fn.getcwd() .. "/lua/?.lua;" .. vim.fn.getcwd() .. "/lua/?/init.lua;" .. package.path

		local terms = require("plugins.toggleterm.terms")
		terms.focus({ key = "agent" })
		terms.toggle_panel({ key = "agent", dir = require("plugins.toggleterm.terms.get_query_fn").any })
		sent({ type = "dir", value = "/project" })
		sent({ type = "status", value = "working" })
		sent({ type = "detach" })

		result = {
			activated = activated,
			dir = item.dir,
			item_count = #result_items,
			events = events,
		}
	]])

	assert.same({
		activated = "toggleterm",
		dir = "/project",
		item_count = 1,
		events = { "dir", "status", "detach" },
	}, child.lua_get("result"))
end

return T
