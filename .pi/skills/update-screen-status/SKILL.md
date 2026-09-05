---
name: update-screen-status
description: Reconcile lua/plugins/toggleterm/terms/screen_status.lua with the latest herdr (github.com/herdrdev/herdr @ master) detection capabilities. Use when the user says "update screen_status.lua from herdr", "sync screen status with herdr", or wants the Lua engine to support the same matchers, regions, and rule fields herdr ships.
---

# Update `screen_status.lua` from herdr

herdr ships a Rust detection engine whose TOML manifests already exercise matchers, regions, and rule fields this repo's Lua engine does not implement. This skill closes that gap in `lua/plugins/toggleterm/terms/screen_status.lua` (and, only when unavoidable, its spec and callers).

The contract is **capabilities**, not rule content. `config.lua`'s `screen_manifests` table stays the source of truth for which rules this repo actually runs; this skill never edits rules or adds new agents.

## Inputs

- Local: `lua/plugins/toggleterm/terms/screen_status.lua`
- Local: `tests/toggleterm/screen_status_spec.lua`
- Local (read-only context, never edited by this skill): `lua/plugins/toggleterm/terms/attach_term.lua`, `lua/plugins/toggleterm/config.lua`
- Remote: `https://raw.githubusercontent.com/herdrdev/herdr/master/src/detect/manifest.rs`
- Remote: `https://raw.githubusercontent.com/herdrdev/herdr/master/src/detect/manifests/*.toml` — fetch the full directory listing once, then every file
- Test runner: `./scripts/test tests/toggleterm/screen_status_spec.lua`

## Workflow

### 1. Snapshot herdr

1. Fetch `manifest.rs` — the canonical schema for `AgentManifest` / `ManifestRule` / `ManifestGate` and the `region()` function that maps region names to substrings.
2. List every file in `src/detect/manifests/` (`github_get_file_contents` on the directory), then fetch each one. The set of `(region, matcher)` combinations used across the manifests is the capability surface that matters.
3. From the schema + manifests, derive three lists:
   - **regions** herdr supports (`region()` fn + every `region = "..."` value seen)
   - **matchers** herdr supports (already covered locally: `contains`, `regex`, `line_regex`; flag any new ones)
   - **rule-level fields** beyond `status` + `priority` (notably `visible_idle`, `visible_blocker`, `visible_working`, `skip_state_update`)

Keep this snapshot in scratch — it's the *herdr side* of the diff.

### 2. Audit the local engine

Read `screen_status.lua` and list what it actually implements, in the same three buckets. Note the public surface: `M.detect(manifest, screen)` returns a status string. Record which matchers and rule fields the local `gate_matches` already handles, and which regions the local `region()` covers.

### 3. Gap list

Produce a table. One row per missing or different item:

| item | herdr | local | action |
| --- | --- | --- | --- |
| region | `top_non_empty_lines(N)` | absent | add `region()` branch |
| region | `osc_title` | absent | requires new input; defer or add |
| ... | ... | ... | ... |

Classify each row as:

- **in-scope** — pure engine work in `screen_status.lua` (+ tests)
- **follow-up** — needs a new caller-side input (e.g. OSC strings); record in the report, don't implement

For matchers (`contains`, `regex`, `line_regex`), `all`, `any`, `not`, and `priority`: the local engine already matches herdr — flag only if the local semantics differ (e.g. case sensitivity, regex flavor). Vim's Lua regex is its own flavor; flag any herdr pattern that won't compile with `vim.regex` and decide between case-by-case rewriting vs. documenting the divergence.

### 4. Plan the change

Before any edit, write a short plan into the chat:

- Public-surface change? `M.detect` may need a new return shape (table vs string) to carry `visible_*` and `skip_state_update`. If so, list every call site (`attach_term.lua`, tests) and the migration for each. **Stop and ask the user before changing the return type** — it's a breaking change.
- New regions and their implementations. For multi-region tricks like `last_non_empty_above_prompt_box` and `whole_recent_without_current_prompt_marker`, sketch the algorithm before coding. The "prompt marker" is whatever line pattern the rule's `line_regex` describes — for the bundled manifests that's `^\s*❯`; for now define a single configurable marker pattern in the engine (default `^\s*❯`) and document the limitation.
- Test cases to add, mirroring herdr's manifest rules where they exercise a *new* capability (don't port rules wholesale).

### 5. Implement

Edit only `lua/plugins/toggleterm/terms/screen_status.lua` and `tests/toggleterm/screen_status_spec.lua`. Keep the diff minimal:

- Extend `region()` with new branches.
- Extend `gate_matches` only if a new matcher shows up in herdr.
- Update `M.detect` if (and only if) the plan above was approved for a return-shape change.
- Add one spec per new region/matcher/rule-field, using realistic strings adapted from herdr manifests.

Do not touch `config.lua` rule tables or `attach_term.lua` plumbing — that's a separate concern (the caller side).

### 6. Verify

```sh
./scripts/test tests/toggleterm/screen_status_spec.lua
```

If anything fails, fix the spec or the implementation — do not relax the spec to pass. If the failure exposes a real herdr/Lua divergence (regex flavor, character class), add a comment in `screen_status.lua` noting it.

### 7. Report

Print a short report:

- **Capabilities added** — list of new regions / matchers / rule fields, with the herdr manifest that exercises each one (filename + rule id).
- **Capabilities deferred** — anything classified as follow-up, with the caller change needed to unlock it.
- **Tests** — paths and one-line description per new spec case.
- **Public surface** — call out any signature change to `M.detect`, with every callsite that needs updating.
- **Spec drift** — divergences between herdr's expected behaviour and the Lua engine that the tests deliberately accept (e.g. "herdr treats `(?i)` case-insensitive flags; vim.regex does not").

The report is the contract. If the user reads only that, they know what changed and what didn't.

## Guardrails

- Never edit `config.lua`'s `screen_manifests` table from this skill — adding rules is a separate intent.
- Never refactor unrelated code in `screen_status.lua` while you're in there. If you spot rot (unused locals, dead branches), mention it in the report and stop.
- Don't bump herdr's pin or read a fork — always `master` of `herdrdev/herdr` unless the user overrides.
- Don't commit. The user runs the commit when they're satisfied.
- If the gap list is empty (herdr and local already match), say so plainly and stop — don't invent work.