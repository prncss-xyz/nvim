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
function M.encode_uri(str)
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
			local escaped = M.encode_uri(value)
			first = false
			query_str = query_str .. sep .. key .. "=" .. escaped
		end
	end
	return query_str
end

---@param base string
---@param query {[string]: string}?
function M.visit(base, query)
	require("plenary").job
		:new({
			command = get_open_cmd(),
			args = { get_url(base, query) },
		})
		:start()
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

local slug_pattern = "%[.+%]"

local file_patterns = {
	"^src/app/(.+)/page%.tsx$",
	"^app/(.+)/page%.tsx$",
}

local default_port = "3000"

local function find_match(path)
	for _, pattern in ipairs(file_patterns) do
		local res = path:match(pattern)
		if res then
			return res
		end
	end
end

local function get_file_url(path, port)
	local res = find_match(path) or ""
	return "http://localhost:" .. port .. "/" .. res
end

function M.server()
	local port = vim.env.PORT or default_port
	return "http://localhost:" .. port .. "/"
end

function M.file(url)
	url = url or get_file_url(vim.fn.expand("%:."), vim.env.PORT or default_port)
	local slug = url:match(slug_pattern)
	if slug then
		vim.ui.input({
			prompt = "input slug " .. slug .. " in " .. url,
		}, function(result)
			if not result or result == "" then
				return
			end
			url = string.gsub(url, require("flies.utils").pattern_escape(slug), result)
			M.file(url)
		end)
		return
	end
	M.visit(url)
end

return M
