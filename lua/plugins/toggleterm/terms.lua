local M = {}

local create_history = require("plugins.toggleterm.history").create_history
local create_term = require("plugins.toggleterm.create_term").create_term
local config = require("plugins.toggleterm.config")
local utils = require("plugins.toggleterm.utils")

local history = create_history("hash")

local function get_hash(o)
	return string.format("%s:%s:%i", o.dir, o.key, o.instance_count)
end

local function transform_dir(dir)
	if dir == "" then
		return nil
	end
	if dir == nil then
		return {
			vim.env.HOME,
			vim.fn.getcwd(),
		}
	end
	return dir
end

local function get_query_fn(o)
	local query = vim.deepcopy(o or {})
	query.prompt = nil
	query.dir = transform_dir(query.dir)
	local count = vim.v.count
	if count > 0 then
		query.instance_count = count
	end
	return function(item)
		for k, v in pairs(query) do
			if type(v) == "table" and vim.islist(v) then
				if not vim.tbl_contains(v, item[k]) then
					return false
				end
			elseif item[k] ~= v then
				return false
			end
		end
		return true
	end
end

local function pad(s, len)
	if #s >= len then
		return s
	end
	return s .. string.rep(" ", len - #s)
end

local pkg_cache = {}

local function get_commands0(cwd)
	if not pkg_cache[cwd] then
		local commands = vim.tbl_extend("force", {}, config.commands)
		require("plugins.toggleterm.package").add_npm_scripts(commands, cwd)
		pkg_cache[cwd] = commands
	end
	return pkg_cache[cwd]
end

local function get_commands(filter)
	local commands = vim.tbl_extend("force", {}, get_commands0(vim.fn.getcwd()))
	local res = {}
	for k, v in pairs(commands) do
		if type(v) == "table" then
			v = vim.tbl_extend("force", {}, v)
		elseif type(v) == "function" then
			v = v()
		end
		if type(v) == "string" then
			v = { cmd = v }
		end
		if v then
			v.key = k
			v.display_name = v.display_name or k
			v.tag = v.tag or k
			v.idle_timeout = v.idle_timeout or config.idle_timeout
			v.instance_count = vim.v.count1
			v.dir = v.dir or vim.fn.getcwd()
			v.hash = get_hash(v)
			if filter(v) then
				res[k] = v
			end
		end
	end
	return res
end

local function prepare()
	-- noop, but also a flag
end

local function make_item(item, cb)
	item.status = "active"
	local once_seen = false
	local term = create_term(item, function(event)
		if event.type == "focus" then
			history.insert(item)
		elseif event.type == "status" then
			once_seen = once_seen or event.seen
			if item.status ~= "exited" then
				item.status = event.value
				if once_seen and event.value == "idle" and not event.seen then
					config.on_idle(item)
				end
			end
		elseif event.type == "detach" then
			history.purge(item.hash)
		end
	end, cb == prepare)
	item.term = term
	history.insert(item)
	cb(item)
end

local status_icons = {
	active = "● ",
	idle = "○ ",
	exited = "✗ ",
}

local function format_item(item)
	local res = status_icons[item.status] or "  "
	res = res .. pad(item.key, 20)
	if item.display_name == item.key then
		return res
	end
	return res .. "  \u{2014}  " .. item.display_name
end

local function with_query(query, cb)
	local filter = get_query_fn(query)
	if query.prompt then
		local items = history.filter(filter)
		if #items > 0 then
			return vim.ui.select(items, {
				prompt = query.prompt,
				format_item = format_item,
			}, function(item)
				if item then
					cb(item)
				end
			end)
		end
		items = utils.all_of(get_commands(filter))
		return vim.ui.select(items, {
			prompt = query.prompt,
			format_item = format_item,
		}, function(item)
			if item then
				make_item(item, cb)
			end
		end)
	end
	local item = history.find(filter)
	if item then
		return cb(item)
	end
	item = utils.first_of(get_commands(filter))
	if item then
		make_item(item, cb)
	end
end

function M.run(query)
	local filter = get_query_fn(query)
	local items = get_commands(filter)
	local choices = {}
	for _, item in pairs(items) do
		local res = history.find(function(i)
			return i.hash == item.hash
		end)
		table.insert(choices, res or item)
	end
	vim.ui.select(choices, {
		prompt = "Select Command: ",
		format_item = format_item,
	}, function(item)
		if not item then
			return
		end
		if item.term then
			return item.term.focus()
		end
		make_item(item, function(instance)
			instance.term.focus()
		end)
	end)
end

function M.focus(query)
	with_query(query, function(instance)
		instance.term.focus()
	end)
end

function M.toggle(query)
	with_query(query, function(instance)
		instance.term.toggle()
	end)
end

function M.prepare(query)
	with_query(query, prepare)
end

function M.send_str(query, str)
	with_query(query, function(instance)
		instance.term.send_str(str)
	end)
end

function M.on_dir()
	for _, v in ipairs(config.autostart) do
		M.prepare(v)
	end
end

return M
