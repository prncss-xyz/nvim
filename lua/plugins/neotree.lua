local win = require("my.parameters").domain.win
local theme = require("my.parameters").theme
local avante = require("my.conds").avante

return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		opts = function()
			local function open_grug_far(prefills)
				local grug_far = require("grug-far")

				if not grug_far.has_instance("explorer") then
					grug_far.open({ instanceName = "explorer" })
				else
					grug_far.get_instance("explorer"):open()
				end
				-- doing it seperately because multiple paths doesn't open work when passed with open
				-- updating the prefills without clearing the search and other fields
				vim.defer_fn(function()
					require("my.ui_toggle").activate("grugfar", function()
						grug_far.get_instance("explorer"):update_input_values(prefills, false)
					end)
				end, 0)
			end
			local khutulun = require("khutulun")
			local events = require("neo-tree.events")
			local function on_move(data)
				Snacks.rename.on_rename_file(data.source, data.destination)
			end
			local function file_cmd(cb)
				return function(state)
					local node = state.tree:get_node()
					local path = node:get_id()
					cb(path)
				end
			end
			return {
				sources = {
					"filesystem",
					"buffers",
					"git_status",
					"document_symbols",
				},
				open_files_do_not_replace_types = {
					"terminal",
					"Trouble",
					"qf",
				},
				default_component_configs = {
					indent = {
						indent_marker = " ",
						last_indent_marker = " ",
					},
					modified = {
						symbol = "",
					},
					name = {
						use_git_status_colors = false,
					},
				},
				close_if_last_window = true,
				filesystem = {
					follow_current_file = {
						enabled = true,
					},
					-- 'open_default', 'disabled'
					use_libuv_file_watcher = true,
					filtered_items = {
						hide_dotfiles = true,
					},
					window = {
						mappings = {
							a = false,
							s = false,
							e = "create",
							gh = "set_root",
							gp = "prev_git_modified",
							gn = "next_git_modified",
							h = "show_help",
							i = "run_command",
							oa = avante("avante_add_files"),
							oo = "system_open",
							oh = "open_split",
							["o;"] = "open_vsplit",
							ow = "open_with_window_picker",
							v = "move",
							yl = "yank_filename",
							yy = "yank_filepath",
							x = "delete",
							["<tab>"] = "preview",
							[";"] = "open",
							f = "fuzzy_finder",
							z = "grug_far_replace",
							["é"] = "filter_on_submit",
							["."] = "toggle_hidden",
						},
					},
					renderers = {
						file = {
							{ "icon" },
							{ "name", use_git_status_colors = true },
							{ "diagnostics" },
							{ "git_status", highlight = "NeoTreeDimText" },
						},
					},
					commands = {
						grug_far_replace = function(state)
							local node = state.tree:get_node()
							local prefills = {
								-- also escape the paths if space is there
								-- if you want files to be selected, use ':p' only, see filename-modifiers
								paths = node.type == "directory" and vim.fn.fnameescape(
									vim.fn.fnamemodify(node:get_id(), ":p")
								) or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h")),
							}
							open_grug_far(prefills)
						end,
						-- https://github.com/nvim-neo-tree/neo-tree.nvim/blob/fbb631e818f48591d0c3a590817003d36d0de691/doc/neo-tree.txt#L535
						grug_far_replace_visual = function(state, selected_nodes, callback)
							local paths = {}
							for _, node in pairs(selected_nodes) do
								-- also escape the paths if space is there
								-- if you want files to be selected, use ':p' only, see filename-modifiers
								local path = node.type == "directory"
										and vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":p"))
									or vim.fn.fnameescape(vim.fn.fnamemodify(node:get_id(), ":h"))
								table.insert(paths, path)
							end
							local prefills = { paths = table.concat(paths, "\n") }
							open_grug_far(prefills)
						end,
						--[[ move = file_cmd(khutulun.move), ]]
						--[[ duplicate = file_cmd(khutulun.duplicate), ]]
						create = file_cmd(khutulun.create),
						--[[ rename = file_cmd(khutulun.rename), ]]
						yank_absolute = file_cmd(khutulun.yank_absolute_filepath),
						yank_filepath = file_cmd(khutulun.yank_relavite_filepath),
						yank_filename = file_cmd(khutulun.yank_filename),
						system_open = file_cmd(function(path)
							vim.api.nvim_command("silent !xdg-open " .. path)
						end),
						run_command = file_cmd(function(path)
							vim.api.nvim_input(": " .. path .. "<Home>")
						end),
						preview = function(state)
							local node = state.tree:get_node()
							if require("neo-tree.utils").is_expandable(node) then
								state.commands["toggle_node"](state)
							else
								state.commands["open"](state)
								vim.cmd("Neotree reveal")
							end
						end,
						avante_add_files = function(state)
							local node = state.tree:get_node()
							local filepath = node:get_id()
							local relative_path = require("avante.utils").relative_path(filepath)

							local sidebar = require("avante").get()

							local open = sidebar:is_open()
							-- ensure avante sidebar is open
							if not open then
								require("avante.api").ask()
								sidebar = require("avante").get()
							end

							sidebar.file_selector:add_selected_file(relative_path)

							-- remove neo tree buffer
							if not open then
								sidebar.file_selector:remove_selected_file("neo-tree filesystem [1]")
							end
						end,
					},
				},
				event_handlers = {
					{ event = events.FILE_MOVED, handler = on_move },
					{ event = events.FILE_RENAMED, handler = on_move },
				},
			}
		end,
		cmd = { "Neotree" },
		keys = {
			{
				win .. theme.buffers,
				function()
					require("my.ui_toggle").activate("neotree", "Neotree buffers")
				end,
				desc = "Neotree buffers",
			},
			{
				win .. theme.directory,
				function()
					require("my.ui_toggle").activate("neotree")
				end,
				desc = "Neotree files",
			},
			{
				win .. theme.hunk,
				function()
					require("my.ui_toggle").activate("neotree", "Neotree git_status")
				end,
				desc = "Neotree git",
			},
		},
	},
}
