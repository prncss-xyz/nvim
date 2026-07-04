local M = {}

local list_urls = [[
output=$(portless list) || exit $?
esc=$(printf '\033')
printf '%s\n' "$output" | sed "s/${esc}\[[0-9;?]*[ -/]*[@-~]//g" | grep -Eo 'https?://[^[:space:])>]+'
status=$?
[ "$status" -eq 1 ] && exit 0
exit "$status"
]]

local function open_url(url)
	if not url or url == "" then
		return
	end

	if vim.ui.open then
		vim.ui.open(url)
		return
	end

	require("my.browser").visit(url)
end

function M.pick()
	if vim.fn.executable("portless") == 0 then
		Snacks.notify.error("Missing required command: portless")
		return
	end

	Snacks.picker.pick({
		title = "Portless",
		finder = function(opts, ctx)
			return require("snacks.picker.source.proc").proc(
				ctx:opts({
					cmd = "sh",
					args = { "-c", list_urls },
					transform = function(item)
						item.url = item.text
					end,
				}),
				ctx
			)
		end,
		format = "text",
		confirm = function(picker, item)
			picker:close()
			open_url(item and item.url or nil)
		end,
		matcher = {
			sort_empty = true,
		},
	})
end

return M
