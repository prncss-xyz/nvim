local M = {}

-- https://github.com/xiyaowong/link-visitor.nvim/blob/main/lua/link-visitor/utils.lua
local function get_open_cmd()
	local uname = vim.loop.os_uname()
	local os = uname.sysname
	if os == "Darwin" then
		return "open"
	end
	if os:find("Windows") or (os == "Linux" and uname.release:lower():find("microsoft")) then
		return 'cmd.exe /c start ""'
	end
	return "xdg-open"
end

-- http://lua-users.org/wiki/StringRecipes
local function encode_uri(str)
	if str then
		str = str:gsub("\n", "\r\n")
		str = str:gsub("([^%w %-%_%.%~])", function(c)
			return ("%%%02X"):format(string.byte(c))
		end)
		str = str:gsub(" ", "+")
	end
	return str
end

---@param base string
---@param query {[string]: string}?
local function get_url(base, query)
	local query_str = base
	if query then
		local first = true
		for key, value in pairs(query) do
			local sep = first and "?" or "&"
			local escaped = encode_uri(value)
			first = false
			query_str = query_str .. sep .. key .. "=" .. escaped
		end
	end
	return query_str
end

---@param base string
---@param query {[string]: string}?
function M.visit(base, query)
	vim.system({ get_open_cmd(), get_url(base, query) }, { detach = true }):wait()
end

function M.link()
	require("flies.ioperations._patterns")
		.from_rules({
			{
				"https?://[%w%d%%-+/.#=:@'?&_]+",
				function(url)
					M.visit(url)
				end,
			},
			{
				"[%w.%-_]+/[%w.%-_]+",
				function(repo)
					M.visit("https://github.com/" .. repo)
				end,
			},
		})
		:exec()
end

local function query_bang(on_confirm)
	vim.ui.input({
		prompt = "ddg !bang",
	}, function(result)
		local bang
		if not result then
			return
		end
		if result == "" then
			bang = ""
		else
			bang = "!" .. result .. " "
		end
		on_confirm(bang)
	end)
end

-- FIX:
function M.search()
	local op = require("flies.operations._with_contents"):new({
		cb = function(_, contents)
			query_bang(function(bang)
				M.visit("https://duckduckgo.com/", {
					t = "ffab",
					q = bang .. table.concat(contents, "\n"),
					ia = "web",
				})
			end)
		end,
	})
	op:call({})
end

return M
