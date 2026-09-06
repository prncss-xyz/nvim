local M = {}

local create_history = require("plugins.toggleterm.terms.history").create_history
local create_term = require("plugins.toggleterm.terms.create_term").create_term
local config = require("plugins.toggleterm.config")
local get_query_fn = require("plugins.toggleterm.terms.get_query_fn").get_query_fn
local utils = require("plugins.toggleterm.terms.utils")
local commands = require("plugins.toggleterm.terms.get_commands")
local get_commands = commands.get_commands
local get_hash = commands.get_hash
local format_item = require("plugins.toggleterm.terms.format_item").format_item
local visit = require("my.browser").visit

local screen_manifests = {
	pi = {
		default_status = "idle",
		rules = {
			{
				id = "status_bar_running",
				status = "working",
				priority = 200,
				region = "bottom_non_empty_lines(3)",
				visible_working = true,
				line_suffix = { "· running" },
			},
			{
				id = "working_literal",
				status = "working",
				priority = 100,
				region = "whole_recent",
				contains = { "Working" },
			},
		},
	},
	claude = {
		default_status = "idle",
		rules = {
			{
				id = "permission_prompt",
				status = "blocked",
				priority = 900,
				region = "after_last_horizontal_rule",
				any = {
					{ contains = { "do you want to proceed?" } },
					{ contains = { "waiting for permission" } },
					{ contains = { "tab to amend" } },
					{ contains = { "esc to cancel", "enter to select" } },
				},
			},
			{
				id = "working_interrupt_hint",
				status = "working",
				priority = 500,
				region = "bottom_non_empty_lines(5)",
				any = {
					{ contains = { "esc to interrupt" } },
					{ contains = { "ctrl+c to interrupt" } },
				},
			},
			{
				id = "prompt",
				status = "idle",
				priority = 100,
				region = "prompt_box_body",
				line_regex = { [[^\s*❯]] },
			},
		},
	},
}

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
	if event.type == "create" then
		history.insert(item)
	elseif event.type == "focus" then
		item.seen = true
		history.insert(item)
	elseif event.type == "status" and event.value ~= item.status then
		item.status = event.value
		item.seen = event.seen == true or item.term.is_in_view()
		config.on_status(item)
	elseif event.type == "url" then
		item.term.url = event.value
	elseif event.type == "detach" then
		local current = history.find(function(candidate)
			return candidate.hash == item.hash
		end)
		if current == item then
			history.purge(item.hash)
		end
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
	item.seen = true
	item.instance_count = vim.v.count1
	item.screen_manifest = screen_manifests[item.key]
	if not item.hash then
		assert(type(item.key) == "string" and item.key ~= "", "Cannot spawn an ad-hoc terminal without a key")
		item.dir = type(item.dir) == "string" and item.dir or vim.fn.getcwd()
		item.hash = get_hash(item)
	end
	if type(item.cmd) == "function" then
		return item.cmd(function(cmd)
			item.cmd = cmd
			create_and_notify(item, cb)
		end)
	end
	create_and_notify(item, cb)
end

local lt_item =
	utils.compose_gt(utils.lt_field("dir", ""), utils.lt_field("key", ""), utils.lt_field("instance_count", 0))

local gt_item = utils.compose_gt(
	utils.gt_field("priority", 0),
	utils.gt_field("dir", ""),
	utils.gt_field("key", ""),
	utils.gt_field("instance_count", 0)
)

local function sort_items(items)
	table.sort(items, lt_item)
	return items
end

local function context_dir()
	local dir = require("plugins.toggleterm.terms.artifact_cwd").resolve(vim.api.nvim_buf_get_name(0))
	if dir then
		return dir
	end
	if vim.bo.buftype == "terminal" then
		local _, term = require("toggleterm.terminal").identify()
		return term and term.dir or nil
	end
end

local function normalize_query(query)
	query = vim.tbl_extend("keep", query or {}, {})
	query.instance_count = vim.v.count > 0 and vim.v.count or nil
	query.dir = query.dir or context_dir() or { vim.fn.getcwd(), vim.env.HOME }
	return query
end

local function get_query_commands(query, filter)
	local cwd = type(query.dir) == "string" and query.dir or nil
	return get_commands(filter, cwd)
end

local function with_query(query, cb)
	query = normalize_query(query)
	local filter = get_query_fn(query)
	if query.prompt then
		local items = sort_items(history.filter(filter))
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
		items = sort_items(utils.all_of(get_query_commands(query, filter)))
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
	item = utils.max_of(get_query_commands(query, filter), gt_item)
	if item then
		make_item(item, cb)
	else
		make_item(query, cb)
	end
end

local local_format_item = format_item(false)

function M.run(query)
	query = normalize_query(query)
	local filter = get_query_fn(query)
	local items = get_query_commands(query, filter)
	local choices = {}
	for _, item in pairs(items) do
		local res = history.find(function(i)
			return i.hash == item.hash
		end)
		table.insert(choices, res or item)
	end
	sort_items(choices)
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

function M.rerun(query)
	query = normalize_query(query)
	local filter = get_query_fn(query)
	local matches = history.filter(filter)
	local item = utils.max_of(get_query_commands(query, filter), gt_item) or matches[1] or query

	if item.term then
		item = vim.tbl_extend("force", {}, item)
		item.term = nil
		item.status = nil
	end
	for _, instance in ipairs(matches) do
		history.purge(instance.hash)
		instance.term.kill()
	end
	make_item(item, function(instance)
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
		require("plugins.toggleterm.terms.panel").toggle(query, history, subscribe, function(dir)
			M.focus({ dir = dir, prompt = "Select Command: " })
		end)
	end)
end

function M.raise_panel()
	require("plugins.toggleterm.terms.panel").open(history, subscribe, function(dir)
		M.focus({ dir = dir, prompt = "Select Command: " })
	end)
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
	local items = sort_items(history.filter(function(item)
		return item.term and item.term.url
	end))
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
