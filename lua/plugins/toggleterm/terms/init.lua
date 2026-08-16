local M = {}

local create_history = require("plugins.toggleterm.terms.history").create_history
local create_term = require("plugins.toggleterm.terms.create_term").create_term
local config = require("plugins.toggleterm.config")
local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn
local utils = require("plugins.toggleterm.terms.utils")
local get_commands = require("plugins.toggleterm.terms.get_commands").get_commands
local format_item = require("plugins.toggleterm.terms.format_item").format_item
local visit = require("my.browser").visit

local history = create_history("hash")
local listeners = {}
local next_listener_id = 0

local function notify(...)
	for _, listener in pairs(listeners) do
		pcall(listener, ...)
	end
end

local function subscribe(listener)
	next_listener_id = next_listener_id + 1
	local id = next_listener_id
	listeners[id] = listener
	return function()
		listeners[id] = nil
	end
end

subscribe(function(event, item)
	if event.type == "create" or event.type == "focus" then
		history.insert(item)
	elseif event.type == "status" and event.value ~= item.status then
		item.status = event.value
		config.on_status(item)
	elseif event.type == "url" then
		item.term.url = event.value
	elseif event.type == "detach" then
		history.purge(item.hash)
	end
end)

local function prepare()
	-- act as noop, but also used as a flag
end

local function create_and_notify(item, cb)
	item.term = create_term(item, function(event)
		notify(event, item)
	end, cb == prepare, config.min_runtime)
	notify({ type = "create" }, item)
	cb(item)
end

local function make_item(item, cb)
	item.status = "idle"
	item.instance_count = vim.v.count1
	if type(item.cmd) == "function" then
		return item.cmd(function(cmd)
			item.cmd = cmd
			create_and_notify(item, cb)
		end)
	end
	create_and_notify(item, cb)
end

local gt_item = utils.compose_gt(
	utils.gt_field("priority", 0),
	utils.lt_field("instance_count"),
	utils.gt_field("key"),
	utils.gt_field("dir")
)

local function normalize_query(query)
	query = vim.tbl_extend("keep", query or {}, {})
	query.instance_count = vim.v.count > 0 and vim.v.count or nil
	query.dir = query.dir or { vim.fn.getcwd(), vim.env.HOME }
	return query
end

local function with_query(query, cb)
	query = normalize_query(query)
	local filter = get_query_fn(query)
	if query.prompt then
		local items = history.filter(filter)
		if #items > 0 then
			return vim.ui.select(items, {
				prompt = query.prompt,
				format_item = format_item(query.dir == require("plugins.toggleterm.terms.get_query_fn").any),
			}, function(item)
				if item then
					cb(item)
				end
			end)
		end
		items = utils.all_of(get_commands(filter))
		return vim.ui.select(items, {
			prompt = query.prompt,
			format_item = format_item(query.dir == vim.env.HOME),
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
	item = utils.max_of(get_commands(filter), gt_item)
	if item then
		make_item(item, cb)
	end
end

local local_format_item = format_item(false)

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
	table.sort(choices, function(a, b)
		return local_format_item(a) < local_format_item(b)
	end)
	vim.ui.select(choices, {
		prompt = "Select Command: ",
		format_item = local_format_item,
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

function M.toggle_panel(query)
	query = normalize_query(query)
	require("my.ui_toggle").activate("toggleterm", function()
		require("plugins.toggleterm.terms.panel").toggle(query, history, subscribe)
	end)
end

function M.raise_panel()
	require("plugins.toggleterm.terms.panel").open(history, subscribe)
end

function M.prepare(query)
	with_query(query, prepare)
end

function M.send_str(query, str)
	with_query(query, function(instance)
		if type(str) == "function" then
			local ctx = require("plugins.toggleterm.terms.window").get_ctx()
			if ctx then
				str = str(ctx, instance)
			else
				return
			end
		end
		instance.term.send_str(str)
	end)
end

function M.read(hash, opts, cb)
	local item = history.find(function(candidate)
		return candidate.hash == hash
	end)
	if not item then
		return
	end
	return item.term.read(opts.len, opts.regex, cb)
end

function M.browse()
	local items = history.filter(function(item)
		return item.term and item.term.url
	end)
	vim.ui.select(items, {
		prompt = "Select Terminal URL",
		format_item = function(item)
			return string.format("%s  —  %s", format_item(true)(item), item.term.url)
		end,
	}, function(item)
		if item then
			visit(item.term.url)
		end
	end)
end

function M.restart(query)
	with_query(query, function(instance)
		instance.term.restart()
	end)
end

local seen = {}

function M.on_dir()
	local cwd = vim.fn.getcwd()
	if seen[cwd] then
		return
	end
	seen[cwd] = true
	for _, v in ipairs(config.autostart) do
		M.prepare(v)
	end
end

return M
