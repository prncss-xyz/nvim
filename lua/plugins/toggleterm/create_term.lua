local M = {}

local Terminal = require("toggleterm.terminal").Terminal
local start_idle_detection = require("plugins.toggleterm.idle").start_idle_detection
local last_terminal
local window = require("plugins.toggleterm.window")
local is_visible = window.is_visible

function M.create_term(config, send, prepare)
	local o = vim.deepcopy(config)
	o.on_open = function()
		vim.schedule(function()
			vim.cmd.startinsert()
		end)
	end

	function o.on_exit()
		send({
			type = "status",
			value = "exited",
		})
	end

	local term = Terminal:new(o)
	if prepare then
		term:spawn()
	end
	vim.schedule(function()
		if term and term.bufnr and term.bufnr > 0 then
			start_idle_detection(term, config.idle_timeout, send)
		end
	end)

	local function hide_last()
		if last_terminal ~= nil and last_terminal ~= term then
			local winnr = last_terminal.window
			if winnr and vim.api.nvim_win_is_valid(winnr) then
				last_terminal:toggle()
				return true
			end
		end
		last_terminal = nil
		return false
	end

	local function toggle()
		if hide_last() then
			return
		end
		if not is_visible(term.window) then
			last_terminal = term
		end
		term:toggle()
	end

	local function focus()
		hide_last()
		if not is_visible(term.window) then
			term:toggle()
			last_terminal = term
		end
	end

	return {
		toggle = toggle,
		focus = focus,
		send_str = function(str, start_insert)
			focus()
			vim.schedule(function()
				vim.api.nvim_chan_send(term.job_id, str)
				if start_insert then
					vim.schedule(function()
						vim.cmd.startinsert()
					end)
				end
			end)
		end,
	}
end

return M
