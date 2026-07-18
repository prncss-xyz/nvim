local M = {}
local create_history = require("plugins.toggleterm.terms.history").create_history
local create_term = require("plugins.toggleterm.terms.create_term").create_term
local config = require("plugins.toggleterm.config")
local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn
local utils = require("plugins.toggleterm.terms.utils")
local get_commands = require("plugins.toggleterm.terms.get_commands").get_commands
local format_item = require("plugins.toggleterm.terms.format_item").format_item
local visit = require("my.browser").visit
local is_in_view = require("plugins.toggleterm.terms.window").is_in_view

local history = create_history("hash")

local function prepare()
	-- act as noop, but also used as a flag
end

local function make_item(item, cb)
	item.status = "alive"
	item.instance_count = vim.v.count1
	local term
	term = create_term(item, function(event)
		if event.type == "focus" then
			history.insert(item)
		elseif event.type == "url" then
			term.url = event.value
		elseif event.type == "detach" then
			history.purge(item.hash)
		end
	end, cb == prepare)
	item.term = term
	history.insert(item)
	cb(item)
end

local gt_item = utils.compose_gt(
	utils.gt_field("priority", 0),
	utils.lt_field("instance_count"),
	utils.gt_field("key"),
	utils.gt_field("dir")
)

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
	item = utils.max_of(get_commands(filter), gt_item)
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
	table.sort(choices, function(a, b)
		return format_item(a) < format_item(b)
	end)
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

function M.set_status(hash, status)
	local item = history.find(function(candidate)
		return candidate.hash == hash
	end)
	if not item then
		return
	end
	item.status = status
	if not is_in_view(item.term.window) then
		config.on_status(item)
	end
end

function M.browse()
	local items = history.filter(function(item)
		return item.term and item.term.url
	end)
	vim.ui.select(items, {
		prompt = "Select Terminal URL",
		format_item = function(item)
			return string.format("%s  —  %s", format_item(item), item.term.url)
		end,
	}, function(item)
		if item then
			visit(item.term.url)
		end
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
