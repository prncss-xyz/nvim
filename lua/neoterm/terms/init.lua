local M = {}

local create_history = require("neoterm.terms.history").create_history
local Term = require("neoterm.terms.create_term")
local config = require("neoterm.config")
local get_query_fn = require("neoterm.terms.get_query_fn").get_query_fn
local utils = require("neoterm.terms.sort_utils")
local commands = require("neoterm.terms.get_commands")
local get_commands = commands.get_commands
local format_item = require("neoterm.terms.format_item").format_item
local create_pseudo_terminal = require("neoterm.terms.pseudo_terminal").create

local history = create_history("instance_count")
local instance_owners = {}
local listeners = {}
local next_listener_id = 0
local working_count = 0

local function update_working_count(delta)
	local was_working = working_count > 0
	working_count = working_count + delta
	assert(working_count >= 0, "Working terminal count cannot be negative")
	local is_working = working_count > 0
	if is_working ~= was_working and config.on_working_change then
		config.on_working_change(is_working)
	end
end

local function available_instance(requested_instance)
	if requested_instance then
		assert(not instance_owners[requested_instance], "Terminal instance number is already in use")
	end
	local instance_count = requested_instance or 1
	while instance_owners[instance_count] do
		instance_count = instance_count + 1
	end
	return instance_count
end

local function reserve_instance(item, requested_instance)
	local instance_count = available_instance(requested_instance)
	instance_owners[instance_count] = item
	item.instance_count = instance_count
end

local function release_instance(item)
	if instance_owners[item.instance_count] == item then
		instance_owners[item.instance_count] = nil
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

local artifact
artifact = create_pseudo_terminal(function()
	artifact.changed = nil
	history.insert(artifact)
end)
artifact.artifact = true
artifact.instance_count = 1
artifact.status = "idle"
instance_owners[1] = artifact
history.insert(artifact)

local function apply_event(event, item)
	if event.type == "create" then
		history.insert(item)
	elseif event.type == "focus" then
		item.changed = nil
		history.insert(item)
	elseif event.type == "status" and event.value ~= item.status then
		local was_working = item.status == "working"
		local is_working = event.value == "working"
		if was_working ~= is_working then
			update_working_count(is_working and 1 or -1)
			item.working_counted = is_working
		end
		item.status = event.value
		item.term.status_changed_at = os.time()
		if event.visible == true or item.term:is_in_view() then
			item.changed = nil
		else
			item.changed = true
			config.on_status(item)
		end
	elseif event.type == "url" and not vim.tbl_contains(item.term.url, event.value) then
		table.insert(item.term.url, event.value)
	elseif event.type == "title" then
		item.title = event.value ~= "" and event.value or nil
	elseif event.type == "cwd" then
		history.insert(item)
	elseif event.type == "detach" then
		if item.working_counted then
			update_working_count(-1)
			item.working_counted = false
		end
		local current = history.find(function(candidate)
			return candidate.instance_count == item.instance_count
		end)
		if current == item then
			history.purge(item.instance_count)
		end
		vim.schedule(function()
			local replacement = history.find(function(candidate)
				return candidate.instance_count == item.instance_count
			end)
			if replacement ~= item then
				release_instance(item)
			end
		end)
	end
end

local function notify(event, item)
	apply_event(event, item)
	for _, listener in pairs(listeners) do
		pcall(listener, event, item)
	end
end

local function prepare()
	-- act as noop, but also used as a flag
end

local function normalize_cmd(cmd)
	if vim.islist(cmd) then
		return table.concat(
			vim.tbl_map(function(value)
				return string.format("%q", value)
			end, cmd),
			" "
		)
	end
	return cmd
end

local function create_and_notify(item, cb)
	item.cmd = normalize_cmd(item.cmd)
	item.term = Term:new({
		cmd = item.cmd,
		cwd = item.cwd,
		instance_count = item.instance_count,
		exit_policy = item.exit_policy,
		screen_manifest = item.screen_manifest,
		auto_scroll = item.auto_scroll,
	}, function(event)
		if event.type == "cwd" then
			item.cwd = event.value
		end
		notify(event, item)
	end, cb == prepare, config.min_runtime, config.notify)
	notify({ type = "create" }, item)
	cb(item)
end

local function make_item(item, cb, requested_instance)
	item.status = item.status or "idle"
	item.changed = nil
	reserve_instance(item, requested_instance)
	assert(type(item.key) == "string" and item.key ~= "", "Cannot spawn an ad-hoc terminal without a key")
	item.cwd = type(item.cwd) == "string" and item.cwd or vim.fn.getcwd()
	local function spawn()
		item = require("neoterm.terms.middlewares").apply_middleware(item)
		instance_owners[item.instance_count] = item
		create_and_notify(item, cb)
	end
	local function create()
		if type(item.cmd) == "function" then
			return item.cmd(function(cmd)
				item.cmd = cmd
				spawn()
			end)
		end
		spawn()
	end
	require("neoterm.git").ensure_worktree(item.cwd, function(ok)
		if ok then
			create()
		else
			release_instance(item)
		end
	end)
end

local lt_item =
	utils.compose_gt(utils.lt_field("cwd", ""), utils.lt_field("key", ""), utils.lt_field("instance_count", 0))

local gt_item = utils.compose_gt(
	utils.gt_field("priority", 0),
	utils.gt_field("cwd", ""),
	utils.gt_field("key", ""),
	utils.gt_field("instance_count", 0)
)

local function normalize_query(query)
	query = vim.tbl_extend("keep", query or {}, {})
	query.instance_count = vim.v.count > 0 and vim.v.count or query.instance_count
	query.cwd = query.cwd or require("neoterm.terms.artifacts.cwd").context_dir() or { vim.fn.getcwd(), vim.env.HOME }
	return query
end

local function get_filter(query)
	local include_artifact = query.artifact == true or query.key == "artifact" or query.instance_count == 1
	local regular_query = vim.tbl_extend("force", {}, query)
	regular_query.artifact = nil
	local regular_filter = get_query_fn(regular_query)
	if not include_artifact then
		return function(item)
			return not item.artifact and regular_filter(item)
		end
	end
	local artifact_query = vim.tbl_extend("force", {}, regular_query)
	artifact_query.cwd = nil
	local artifact_filter = get_query_fn(artifact_query)
	return function(item)
		if item.artifact then
			return artifact_filter(item)
		end
		return regular_filter(item)
	end
end

local function without_query_options(query)
	local item = vim.tbl_extend("force", {}, query)
	item.artifact = nil
	return item
end

local function get_query_commands(query, filter, callback)
	local cwd = type(query.cwd) == "string" and query.cwd or nil
	get_commands(filter, cwd, callback)
end

local function with_query(query, cb)
	query = normalize_query(query)
	if query.instance_count then
		local instance = history.find(get_filter({ instance_count = query.instance_count }))
		if instance then
			return cb(instance)
		end
	end
	local filter = get_filter(query)
	if query.prompt then
		local items = history.filter(filter)
		table.sort(items, lt_item)
		if #items > 0 then
			return vim.ui.select(items, {
				prompt = query.prompt,
				format_item = format_item(query.cwd == require("neoterm.terms.get_query_fn").any),
			}, function(item)
				if item then
					cb(item)
				end
			end)
		end
		return get_query_commands(query, filter, function(commands)
			items = utils.all_of(commands)
			table.sort(items, lt_item)
			vim.ui.select(items, {
				prompt = query.prompt,
				format_item = format_item(query.cwd == vim.env.HOME),
			}, function(item)
				if item then
					make_item(item, function(instance)
						cb(instance, true)
					end, query.instance_count)
				end
			end)
		end)
	end
	local item = history.find(filter)
	if item then
		return cb(item)
	end
	get_query_commands(query, filter, function(commands)
		item = utils.max_of(commands, gt_item)
		local function created(instance)
			cb(instance, true)
		end
		if item then
			make_item(item, created, query.instance_count)
		else
			make_item(without_query_options(query), created, query.instance_count)
		end
	end)
end

local local_format_item = format_item(false)

function M.run_or_raise(query)
	query = normalize_query(query)
	if query.instance_count then
		local instance = history.find(get_filter({ instance_count = query.instance_count }))
		if instance then
			return instance.term:focus()
		end
	end
	local filter = get_filter(query)
	local selected = history.find(filter)
	if selected and selected.artifact then
		return selected.term:focus()
	end
	get_query_commands(query, filter, function(items)
		local choices = history.filter(filter)
		local instance_count = available_instance(query.instance_count)
		for _, item in pairs(items) do
			item.instance_count = instance_count
			local res = history.find(function(i)
				return i.instance_count == item.instance_count and i.key == item.key
			end)
			if not res then
				table.insert(choices, item)
			end
		end
		table.sort(choices, lt_item)
		vim.ui.select(choices, {
			prompt = "Select Command: ",
			format_item = local_format_item,
		}, function(item)
			if not item then
				return
			end
			if item.term then
				return item.term:focus()
			end
			make_item(item, function(instance)
				instance.term:focus()
			end, query.instance_count)
		end)
	end)
end

function M.focus(query)
	with_query(query, function(instance)
		instance.term:focus()
	end)
end

function M.toggle(query)
	with_query(query, function(instance)
		instance.term:toggle()
	end)
end

function M.has_changed()
	return history.find(function(item)
		return item.changed ~= nil
	end) ~= nil
end

function M.has_working()
	return working_count > 0
end

function M.toggle_unseen_or_latest(query)
	query = normalize_query(query)
	if query.instance_count then
		return M.toggle(query)
	end
	local filter = get_filter(query)
	local oldest_changed
	for _, instance in
		ipairs(history.filter(function(candidate)
			return filter(candidate) and candidate.changed
		end))
	do
		if not oldest_changed or instance.term.status_changed_at < oldest_changed.term.status_changed_at then
			oldest_changed = instance
		end
	end
	if oldest_changed then
		return oldest_changed.term:focus()
	end
	M.toggle(query)
end

local panel_history = {
	filter = function(filter)
		return history.filter(function(item)
			return item.cwd ~= nil and filter(item)
		end)
	end,
}

function M.toggle_panel(query)
	query = normalize_query(query)
	local selected = history.find(get_filter(query))
	if selected and selected.toggle_panel then
		return selected.toggle_panel()
	end
	require("neoterm.terms.term_panel").toggle(query, panel_history, subscribe, function(dir)
		M.focus({ cwd = dir, prompt = "Select Command: " })
	end)
end

function M.raise_panel()
	require("neoterm.terms.term_panel").open(panel_history, subscribe, function(dir)
		M.focus({ cwd = dir, prompt = "Select Command: " })
	end)
end

function M.prepare(query)
	with_query(query, prepare)
end

local function prepare_put(arg)
	local invocation
	if type(arg) == "string" then
		local put = require("neoterm.put.init")
		invocation = put.capture(arg)
		arg = put.template(arg)
	end
	return invocation, arg
end

local function put(instance, invocation, arg)
	local ctx = instance.term.get_ctx and instance.term.get_ctx(invocation)
		or require("neoterm.terms.window").get_ctx(invocation)
	if ctx then
		arg = arg(ctx, instance)
	else
		return
	end
	instance.term:put(arg, true)
end

function M.put(query, arg, opts)
	local invocation
	invocation, arg = prepare_put(arg)
	if opts and opts.new then
		query = normalize_query(query)
		return get_query_commands(query, get_filter(query), function(commands)
			local item = utils.max_of(commands, gt_item) or without_query_options(query)
			make_item(item, function(instance)
				put(instance, invocation, arg)
			end, query.instance_count)
		end)
	end
	with_query(query, function(instance)
		put(instance, invocation, arg)
	end)
end

function M.read(instance_count, opts, cb)
	local item = history.find(function(candidate)
		return candidate.instance_count == instance_count
	end)
	if not item then
		return
	end
	return item.term:read(opts, cb)
end

function M.browse()
	local choices = {}
	for _, item in
		ipairs(history.filter(function(candidate)
			return candidate.term and candidate.term.url and #candidate.term.url > 0
		end))
	do
		for _, url in ipairs(item.term.url) do
			table.insert(choices, { item = item, url = url })
		end
	end
	table.sort(choices, function(a, b)
		return lt_item(a.item, b.item)
	end)
	vim.ui.select(choices, {
		prompt = "Select Terminal URL",
		format_item = function(choice)
			return string.format("%s  —  %s", format_item(true)(choice.item), choice.url)
		end,
	}, function(choice)
		if choice then
			vim.system({ config.browser(), choice.url }, { detach = true })
		end
	end)
end

function M.start(query)
	query = normalize_query(query)
	local existing = history.find(get_filter(query))
	if existing and existing.start then
		return existing.start()
	end
	if query.instance_count and history.find(get_filter({ instance_count = query.instance_count })) then
		vim.notify(string.format("Terminal instance %d already exists", query.instance_count), vim.log.levels.ERROR)
		return
	end
	get_query_commands(query, get_filter(query), function(commands)
		local item = utils.max_of(commands, gt_item) or without_query_options(query)
		make_item(item, function(instance)
			instance.term:focus()
		end, query.instance_count)
	end)
end

function M.restart(query)
	with_query(query, function(instance, created)
		if not created then
			instance.term:restart()
		end
	end)
end

return M
