local file = require("my.parameters").domain.file
local theme = require("my.parameters").theme

return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		opts = function()
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
					"edgy",
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
							oa = "avante_add_files",
							oo = "system_open",
							oh = "open_split",
							os = "open_vsplit",
							ow = "open_with_window_picker",
							q = false,
							v = "move",
							yl = "yank_filename",
							yy = "yank_filepath",
							x = "delete",
							["<tab>"] = "preview",
							[";"] = "open",
							["é"] = "fuzzy_finder",
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
				file .. theme.buffers,
				"<cmd>Neotree buffers<cr>",
				desc = "Neotree buffers",
			},
			{
				file .. theme.file,
				"<cmd>Neotree<cr>",
				desc = "Neotree files",
			},
			{
				file .. theme.hunk,
				"<cmd>Neotree git_status<cr>",
				desc = "Neotree git",
			},
			{
				file .. theme.symbol,
				"<cmd>Neotree document_symbols<cr>",
				desc = "Neotree symbols",
			},
		},
	},
}
