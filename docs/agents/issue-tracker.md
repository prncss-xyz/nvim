# Issue tracker: Local Markdown

Issues and specs (also called PRDs) for this repo live as Markdown files in `.artifacts/`.

## Conventions

- One feature per directory: `.artifacts/<feature-slug>/`
- The spec is `.artifacts/<feature-slug>/spec.md`
- Implementation issues are one file per ticket at `.artifacts/<feature-slug>/issues/<NN>-<slug>.md`, numbered from `01`
- Triage state, when needed, is recorded as a `Status:` line near the top
- Comments and conversation history append under a `## Comments` heading

## When a skill says "publish to the issue tracker"

Create a new file under `.artifacts/<feature-slug>/`, creating the directory if needed.

## When a skill says "fetch the relevant ticket"

Read the referenced file. The user will normally pass its path or issue number directly.

## Wayfinding operations

- **Map:** `.artifacts/<effort>/map.md`
- **Child ticket:** `.artifacts/<effort>/issues/NN-<slug>.md`
- **Blocking:** record `Blocked by: NN, NN` near the top
- **Frontier:** choose the first numbered open, unblocked, unclaimed issue
- **Claim:** set `Status: claimed` before beginning work
- **Resolve:** append an `## Answer`, set `Status: resolved`, then add a context pointer to the map
