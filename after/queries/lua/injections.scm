;; highlight string as lua if starts with `-- lua`
(string content: _ @injection.content
 (#lua-match? @injection.content "^%s*%-+%s?lua")
 (#set! injection.language "lua"))
