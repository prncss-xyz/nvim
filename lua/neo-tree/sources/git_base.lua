---Custom neo-tree source: git_status with a configurable diff base (default "main").
---@class neotree.sources.GitBase : neotree.Source

local git = require("neo-tree.git")
local git_status = require("neo-tree.sources.git_status")
local items = require("neo-tree.sources.git_status.lib.items")
local renderer = require("neo-tree.ui.renderer")
local manager = require("neo-tree.sources.manager")
local events = require("neo-tree.events")
local utils = require("neo-tree.utils")

---@type neotree.sources.GitBase
local M = {
	name = "git_base",
	display_name = " 󰊢 Git ",
	-- Reuse git_status components and commands so neo-tree setup can resolve them.
	components = require("neo-tree.sources.git_status.components"),
	commands = require("neo-tree.sources.git_status.commands"),
}

---@type string
M.config_git_base = "main"

---@type fun(base: string)?
M.config_on_base_change = nil

M._on_base_change_last = {}

local wrap = function(func)
	return utils.wrap(func, M.name)
end

local get_state = function()
	return manager.get_state(M.name)
end

---Ensure git_base_by_worktree is set for the worktree containing `path`.
---Respects: 1) already-set base (from command arg), 2) configured default.
---@param state neotree.State
---@param path string
local ensure_default_base = function(state, path)
	state.git_base_by_worktree = state.git_base_by_worktree or {}
	local worktree_root = git.find_worktree_info(path or vim.fn.getcwd())
	if worktree_root and not rawget(state.git_base_by_worktree, worktree_root) then
		state.git_base_by_worktree[worktree_root] = M.config_git_base
	end
end

---Navigate to the given path.
---@param path string Path to navigate to. If empty, will navigate to the cwd.
M.navigate = function(state, path, path_to_reveal, callback, async)
	state.path = path or state.path
	state.dirty = false
	if path_to_reveal then
		renderer.position.set(state, path_to_reveal)
	end
	ensure_default_base(state, state.path)

	-- Notify on_base_change callback when the effective git base changes
	if M.config_on_base_change then
		local worktree_root = git.find_worktree_info(state.path)
		if worktree_root then
			local current = state.git_base_by_worktree[worktree_root]
			if current and current ~= M._on_base_change_last[worktree_root] then
				M._on_base_change_last[worktree_root] = current
				M.config_on_base_change(current)
			end
		end
	end

	-- Temporarily patch git.status so the base diff survives cache-hits.
	-- Upstream bug: when raw status text is unchanged the cache-hit path
	-- returns only (status, root) and omits the third return value.
	-- We wrap it locally during the navigate call to avoid global state.
	local original_status = git.status
	git.status = function(p, bl, sb, so)
		local gs, wr, gsob = original_status(p, bl, sb, so)
		if bl and not gsob and wr and gs then
			local b = bl[wr]
			if b then
				gsob = require("neo-tree.git.diff").diff_name_status(wr, b, sb)
			end
		end
		return gs, wr, gsob
	end

	items.get_git_status(state)

	git.status = original_status

	if type(callback) == "function" then
		vim.schedule(callback)
	end
end

M.refresh = function()
	manager.refresh(M.name)
end

---@param config neotree.Config.GitStatus
---@param global_config neotree.Config.Base
M.setup = function(config, global_config)
	-- Read the configured default base branch from user config.
	-- Falls back to "main" when omitted.
	M.config_git_base = config.git_base or "main"

	-- Optional callback invoked when the effective git base changes.
	-- Receives the base string (e.g. "main", "HEAD~1").
	M.config_on_base_change = config.on_base_change

	if config.before_render then
		manager.subscribe(M.name, {
			event = events.BEFORE_RENDER,
			handler = function(state)
				local this_state = get_state()
				if state == this_state then
					config.before_render(this_state)
				end
			end,
		})
	end

	if global_config.enable_refresh_on_write then
		manager.subscribe(M.name, {
			event = events.VIM_BUFFER_CHANGED,
			handler = function(args)
				if utils.is_real_file(args.afile) then
					M.refresh()
				end
			end,
		})
	end

	if config.bind_to_cwd then
		manager.subscribe(M.name, {
			event = events.VIM_DIR_CHANGED,
			handler = M.refresh,
		})
	end

	if global_config.enable_diagnostics then
		manager.subscribe(M.name, {
			event = events.STATE_CREATED,
			handler = function(state)
				state.diagnostics_lookup = utils.get_diagnostic_counts()
			end,
		})
		manager.subscribe(M.name, {
			event = events.VIM_DIAGNOSTIC_CHANGED,
			handler = wrap(manager.diagnostics_changed),
		})
	end

	if global_config.enable_modified_markers then
		manager.subscribe(M.name, {
			event = events.VIM_BUFFER_MODIFIED_SET,
			handler = wrap(manager.opened_buffers_changed),
		})
	end

	manager.subscribe(M.name, {
		event = events.GIT_EVENT,
		handler = M.refresh,
	})
end

return M
