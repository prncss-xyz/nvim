-- Auto-confirm: when filtering narrows the list to a single item, run the
-- confirm action immediately. Extends snacks' built-in `auto_confirm` (which
-- only fires before the picker is shown) to cover narrowing-by-typing.
--
-- Detection: debounce on `list:add` / `list:update`. Each add/update (re)starts
-- a short timer; when it fires with count==1, we confirm. The debounce means
-- we don't fire on the transient count==1 of an initial streaming load (adds
-- keep coming and reset the timer), only when the list has actually settled.
--
-- For live pickers (grep), we additionally wait for finder+matcher to go idle
-- so we don't confirm on a partial stream.
--
-- Confirm: feed `<CR>` to the input window. This triggers the exact same keymap
-- path as pressing <CR> manually, so the behavior (instant file load for both
-- new and already-loaded buffers, no normal-mode flash) matches manual
-- confirmation. Calling the action directly from a timer callback hits M.jump's
-- insert-mode guard (stopinsert + vim.schedule), and the scheduled re-run only
-- fires on the next event — with the picker blocked on input, that's the next
-- keypress (off-by-one). Feeding the key avoids that because the typeahead is
-- processed in the same event loop cycle as a real keypress.
local M = {}

local uv = vim.uv or vim.loop

---@param picker snacks.Picker
local function confirm_now(picker)
	local win = picker.input.win
	if not win or not win:valid() then
		return
	end
	-- make sure the input window is focused so <CR> routes to the right buffer
	pcall(vim.api.nvim_set_current_win, win.win)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, true, true), "im", false)
end

---@param picker snacks.Picker
function M.attach(picker)
	local list = picker.list
	local timer = assert(uv.new_timer())
	local confirmed = false
	-- debounce: ms of quiet (no adds/updates) before confirming.
	local DEBOUNCE = 30

	local check_wrapped
	local function check()
		if confirmed or picker.closed or not picker.shown then
			return
		end
		if list:count() ~= 1 then
			return
		end
		-- pickers stream results (both finders and matchers are async); wait for
		-- them to settle so we don't jump on a partial result set.
		if picker:is_active() then
			return timer:start(DEBOUNCE, 0, check_wrapped)
		end
		confirmed = true
		if not timer:is_closing() then
			pcall(timer.close, timer)
		end
		confirm_now(picker)
	end
	check_wrapped = vim.schedule_wrap(check)

	local function schedule()
		if confirmed or picker.closed then
			return
		end
		timer:stop()
		timer:start(DEBOUNCE, 0, check_wrapped)
	end

	local add = list.add
	---@diagnostic disable-next-line: duplicate-set-field
	list.add = function(self, item, sort)
		add(self, item, sort)
		if self:count() == 1 then
			schedule()
		end
	end

	local update = list.update
	---@diagnostic disable-next-line: duplicate-set-field
	list.update = function(self, opts)
		update(self, opts)
		if list:count() == 1 then
			schedule()
		end
	end

	local close = picker.close
	---@diagnostic disable-next-line: duplicate-set-field
	picker.close = function(...)
		if not timer:is_closing() then
			pcall(timer.close, timer)
		end
		if close then
			return close(...)
		end
	end
end

---@param opts snacks.picker.Config
function M.config(opts)
	opts = opts or {}
	local prev_on_show = opts.on_show
	---@diagnostic disable-next-line: duplicate-set-field
	opts.on_show = function(picker)
		if prev_on_show then
			prev_on_show(picker)
		end
		M.attach(picker)
	end
	return opts
end

return M
