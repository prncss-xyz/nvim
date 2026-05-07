# Plan: replace `toggleterm.nvim` with Neovim built-in terminal

## Feasibility

This looks **feasible** with **low-to-moderate effort**.

The current code in `lua/plugins/toggleterm/terms.lua` only uses a relatively small slice of `toggleterm`:

- create/reuse named terminals
- toggle/focus a terminal window
- keep one terminal per key and cwd/global scope
- start some terminals in the background
- send text/CR/Ctrl-C/Ctrl-L to terminal jobs
- track the last terminal and tag-based lookups
- clean up cache on exit
- attach idle detection to terminal buffers

All of that can be reproduced with Neovim’s built-in primitives:

- `:terminal` / `vim.fn.termopen()`
- `nvim_open_win()` or split commands
- `nvim_chan_send()`
- `jobstop()`
- `nvim_buf_attach()`
- autocmds like `TermClose`, `BufWipeout`, `DirChanged`

## Main gap vs `toggleterm`

The only meaningful missing abstraction is that `toggleterm` already bundles:

- terminal lifecycle
- split/window reopening
- hidden/background terminal spawning
- persistent terminal object state (`window`, `bufnr`, `job_id`)

So the replacement is mostly about building a small local terminal manager that stores this state explicitly.

## Scope fit

Since you said you do **not** need more than the functionality already used here, this is a good candidate for removal. The codebase does **not** appear to rely on advanced `toggleterm` features like:

- float terminals
n- custom terminal UIs
- direction switching per terminal
- shading/styling features
- terminal-specific commands from the plugin
- multiple complex layouts

## Proposed implementation approach

### 1. Introduce a tiny local terminal state object
Create a replacement module, likely still in `lua/plugins/toggleterm/terms.lua` initially, with records like:

```lua
{
  key = "term_e",
  bufnr = 12,
  job_id = 34,
  winid = 56,
  cmd = "...",
  cwd = "...",
  global = false,
  tag = "agent",
}
```

Keep the existing caches:

- per-cwd terminal cache
- per-cwd tag cache
- `last_terminal`
- `term_to_key`

### 2. Replace `Terminal:new(o)` with explicit creation
For each terminal config:

- create a scratch buffer (or reuse an existing terminal buffer)
- open the terminal in a vertical split when focusing/toggling
- start the job with `vim.fn.termopen(cmd, { cwd = ... , on_exit = ... })`
- for terminals without `cmd`, open an interactive shell using `$SHELL`

Also normalize config keys, because current config mixes `dir` and `cwd`.

### 3. Reimplement `toggle()` semantics locally
Current behavior needed:

- if terminal window is visible: hide it
- otherwise: show it in the configured split
- if switching to a different terminal: hide previous `last_terminal`

This can be done by:

- detecting whether `winid` is valid
- closing that window if visible
- otherwise opening a new vertical split and placing the buffer there

### 4. Support background/auto-start terminals
Current `setup_start()` pre-spawns configured commands in the background.

Built-in equivalent:

- create terminal buffer without showing it permanently
- briefly create it in a hidden split or alternate window context
- start job with `termopen`
- immediately hide/close the window while keeping the buffer/job alive

This is probably the trickiest part, but still very doable.

If hidden startup turns out awkward, a fallback is:

- create the job in a non-displayed terminal buffer
- only open the buffer when focused later

That should be tested, but conceptually it should work.

### 5. Keep the existing public API stable
To minimize fallout, preserve these functions unchanged:

- `select_term()`
- `toggle_last_term()`
- `toggle_term(key)`
- `focus_term(key, conf)`
- `send_str(key, message)`
- `send_lines(key, contents)`
- `send_cr(key)`
- `interrupt(key)`
- `clear(key)`
- `stop(key)`
- `select_command()`
- `setup_start()`
- `get_last_by_tag(key)`

That lets `agents.lua`, `ops.lua`, `my/diff.lua`, and the keymaps continue to work unchanged.

### 6. Reattach idle detection to the terminal buffer
Your current idle detection already uses `nvim_buf_attach()`, so it should transfer almost directly.

The main change is replacing:

- `term.window` -> stored `winid`
- `term.bufnr` -> stored `bufnr`

### 7. Replace cleanup hooks
Today cleanup happens through `o.on_exit` in the `toggleterm` terminal config.

Built-in replacement:

- use `termopen(..., { on_exit = function(...) ... end })`
- optionally add `TermClose` / `BufWipeout` safeguards

On exit, remove the terminal from:

- scope cache
- tag cache
- idle detection state
- `term_to_key`
- `last_terminal` if applicable

### 8. Remove plugin dependency after parity check
After the replacement works:

- remove `akinsho/toggleterm.nvim` from `lua/plugins/toggleterm/init.lua`
- rename the plugin folder if desired (for example `lua/plugins/terminal/`), though this is optional
- remove lazy-loading commands that only existed for the plugin (`ToggleTerm`, etc.)

## Risk areas

### Background spawn behavior
This is the main thing to validate. You rely on `setup_start()` for commands like `tilt` and agent terminals. Make sure hidden startup keeps the job alive after the window closes.

### Window reuse
You will need to decide whether reopening a terminal:

- always creates a fresh vertical split, or
- tries to reuse the old window if still valid

Either is fine as long as toggling/focusing stays consistent.

### `dir` vs `cwd`
Current config uses both:

- `dir = ...`
- `cwd = ...`

The replacement should normalize both to one internal `cwd` field.

### Shell terminals with no `cmd`
Entries like `term_e = {}` currently depend on plugin defaults. The built-in version should explicitly fall back to `vim.o.shell` or `vim.env.SHELL`.

## Suggested migration steps

1. Keep file/module names unchanged for now.
2. Rewrite `lua/plugins/toggleterm/terms.lua` to use only built-in terminal APIs.
3. Preserve the existing exported function names.
4. Test these flows:
   - `oe`, `or`, `ou`, `oo`, `ow`
   - REPL send
   - agent prompt/send/new flows
   - `setup_start()` background terminals
   - idle notifications
   - changing cwd and reopening scoped terminals
5. Once stable, remove `akinsho/toggleterm.nvim` from plugin specs.
6. Optionally rename the module from `toggleterm` to a more neutral `terminal` namespace.

## Recommendation

I would proceed.

This looks like a good cleanup candidate because your usage is narrow, the public API is already centralized in `lua/plugins/toggleterm/terms.lua`, and the rest of the codebase talks to that wrapper rather than directly to `toggleterm`.

That means the migration can stay mostly isolated to one module plus plugin-spec cleanup.