local M = {}

-- copilot-chat
local config = {
	default = "Neotree",
	keys = {
		copilot = {
			ft = { "copilot-chat" },
			raise = "CopilotChat",
		},
		dapview = {
			ft = { "dap-view", "dap-view-term" },
			raise = "DapViewOpen",
		},
		grugfar = {
			ft = { "grug-far" },
			raise = "GrugFar",
		},
		neogit = {
			ft = { "NeogitPopup", "NeogitStatus" },
			raise = "Neogit",
		},
		neotree = {
			ft = { "neo-tree" },
			raise = "Neotree",
		},
		trouble = {
			ft = { "trouble" },
		},
		neotest = {
			ft = { "neotest-summary", "neotest-output-panel" },
		},
	},
}

local function test_ft(ft, v)
	if v.ft == nil then
		return true
	end
	for _, test in ipairs(v.ft) do
		if ft == test then
			return true
		end
	end
end

local function key_from_win(win)
	local bufnr = vim.api.nvim_win_get_buf(win)
	local bt = vim.api.nvim_buf_get_option(bufnr, "buftype")
	if bt == "" then
		return
	end
	local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
	for k, v in pairs(config.keys) do
		if test_ft(ft, v) or test_ft(bt, v) or (v.cb and v.cb(win, bufnr, ft)) then
			return k
		end
	end
end

local function act(value)
	if type(value) == "string" then
		vim.cmd(value)
	elseif type(value) == "function" then
		value()
	end
end

local last_key

-- TODO: skip if already in focus
function M.raise()
  local last = require("my.windows").get_last_n(1)[1]
	if last_key then
		local opts = config.keys[last_key] or {}
		local action = opts.raise
		if action then
			M.activate(last_key, action)
		end
	else
		act(config.default)
	end
end

local function clear(keep_key)
	local empty = true
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local key = key_from_win(win)
		if key and (not keep_key or key ~= keep_key) then
			vim.api.nvim_win_close(win, false)
			empty = false
		end
	end
	if keep_key then
		last_key = keep_key
	end
	return empty
end

function M.activate(key, action)
	action = action or config.keys[key].raise
	clear(key)
	act(action)
end

function M.close()
	clear()
end

function M.toggle()
	local empty = clear()
	if empty then
		M.raise()
	end
end

--[[
  require('dapui').close()
  vim.cmd 'DapVirtualTextDisable'
  require('nvim-dap-virtual-text').disable()
  require('gitsigns').toggle_current_line_blame(true)
--]]
--

return M
