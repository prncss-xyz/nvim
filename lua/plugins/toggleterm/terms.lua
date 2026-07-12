local M = {}
local create_history = require("plugins.toggleterm.history").create_history
local create_term = require("plugins.toggleterm.create_term").create_term
local config = require("plugins.toggleterm.config")

local history = create_history("hash")

local function get_hash(o)
	return string.format("%s:%s:%i", o.dir, o.key, o.instance_count)
end

local function transform_dir(dir)
	if dir == "" then
		return nil
	end
	if dir == nil then
		return vim.fn.getcwd()
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
			if item[k] ~= v then
				return false
			end
		end
		return true
	end
end

local function query_to_key(query)
	if query.key then
		return query.key
	end
	if query.tag then
		local from_tag = config.tags_defaults[query.tag]
		if from_tag then
			return from_tag
		end
	end
	if query.key == nil and query.tag == nil then
		return config.default_terminal
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
		for k, o in pairs(commands) do
			if type(o) == "function" then
				o = o()
			end
			if type(o) == "string" then
				o = { cmd = o }
			end
			commands[k] = o
		end
		pkg_cache[cwd] = commands
	end
	return pkg_cache[cwd]
end

local function get_commands()
	local commands = vim.tbl_extend("force", {}, get_commands0(vim.fn.getcwd()))
	for k, o in pairs(commands) do
		if type(o) == "function" then
			o = o()
		end
		if type(o) == "string" then
			o = { cmd = o }
		end
		commands[k] = o
	end
	return commands
end

local function key_to_item(key)
	local commands = get_commands()
	local o = commands[key]
	if not o then
		return
	end
	local item = vim.tbl_extend("keep", o, {
		key = key,
		display_name = key,
		tag = key,
		idle_timeout = config.idle_timeout,
		instance_count = vim.v.count1,
		dir = vim.fn.getcwd(),
		status = "active",
		-- close_on_exit
	})
	item.hash = get_hash(item)
	return item
end

local function make_item(o, cb)
	local key = query_to_key(o)
	if not key then
		return
	end
	local item = key_to_item(key)
	if not item then
		return
	end
	local term = create_term(item, function(event)
		if event.type == "focus" then
			history.insert(item)
		elseif event.type == "status" then
			if item.status ~= "exited" then
				item.status = event.value
				if event.value == "idle" and not event.in_view then
					config.on_idle(item)
				end
			end
		elseif event.type == "detach" then
			history.purge(item.hash)
		end
	end)
	item.term = term
	history.insert(item)
	cb(item)
end

local status_icons = { idle = "○ ", exited = "✗ " }

local function with_query(o, cb)
	local query_fn = get_query_fn(o)
	if o.prompt then
		local items = history.filter(query_fn)
		if #items > 0 then
			return vim.ui.select(items, {
				prompt = o.prompt,
				format_item = function(item)
					local res = status_icons[item.status] or "  "
					res = res .. pad(item.key, 20)
					if item.display_name == item.key then
						return res
					end
					return res .. "  \u{2014}  " .. item.display_name
				end,
			}, function(item)
				if item then
					cb(item)
				end
			end)
		end
	else
		local item = history.find(query_fn)
		if item then
			return cb(item)
		end
	end
	make_item(o, cb)
end

function M.run()
	local keys = {}
	for key in pairs(get_commands()) do
		if key_to_item(key) then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	vim.ui.select(keys, {
		prompt = "Select Command: ",
	}, function(key)
		if not key then
			return
		end
		M.focus({ key = key })
	end)
end

function M.focus(o)
	with_query(o, function(instance)
		instance.term.focus()
	end)
end

function M.toggle(o)
	with_query(o, function(instance)
		instance.term.toggle()
	end)
end

function M.send_str(o, str)
	with_query(o, function(instance)
		instance.term.send_str(str)
	end)
end

function M.setup_start()
	-- TODO:
end

return M
