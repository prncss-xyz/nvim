# Coding Standards

## Autocmd payloads

`event.data` on `User` autocmds fired by third-party plugins can be nil for some emitters (e.g. gitsigns fires `GitSignsUpdate` without `data` on HEAD changes). Before accepting code that indexes `event.data`, check every emitter of that pattern. Where nil is a legitimate shape, a guard is correct and does not violate the "assertions over defensive programming" rule; flag unguarded indexing in that case.
