local M = {}

local SOURCE = "github-comments"

local cache_by_root = {}

local function joinpath(...)
	if vim.fs and vim.fs.joinpath then
		return vim.fs.joinpath(...)
	end

	return table.concat({ ... }, "/"):gsub("//+", "/")
end

local function decode_json(json)
	if not json or json == "" then
		return nil
	end

	local ok, decoded = pcall(vim.json.decode, json)
	if ok then
		return decoded
	end

	return nil
end

local function flatten_pages(decoded)
	if type(decoded) ~= "table" then
		return {}
	end

	local comments = {}
	for _, value in ipairs(decoded) do
		if type(value) == "table" and value.path then
			table.insert(comments, value)
		elseif type(value) == "table" then
			for _, comment in ipairs(value) do
				if type(comment) == "table" and comment.path then
					table.insert(comments, comment)
				end
			end
		end
	end

	return comments
end

local function run(command, cwd, callback)
	local scheduled_callback = vim.schedule_wrap(callback)

	if vim.system then
		vim.system(command, { cwd = cwd, text = true }, scheduled_callback)
		return
	end

	local previous_cwd = vim.fn.getcwd()
	if cwd then
		vim.fn.chdir(cwd)
	end

	local output = vim.fn.system(command)
	local code = vim.v.shell_error
	vim.fn.chdir(previous_cwd)

	scheduled_callback({
		code = code,
		stdout = output,
		stderr = code == 0 and "" or output,
	})
end

local function comment_author(comment)
	return comment.user and comment.user.login or "unknown"
end

local function comment_preview(comment)
	local preview = (comment.body or ""):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if preview == "" then
		return "GitHub review comment"
	end

	if #preview > 120 then
		return preview:sub(1, 117) .. "..."
	end

	return preview
end

local function build_diagnostics(root, comments)
	return vim.tbl_map(
		function(comment)
			local row = tonumber(comment.line) or 1

			return {
				filename = joinpath(root, comment.path),
				row = math.max(1, row),
				col = 1,
				source = SOURCE,
				severity = vim.diagnostic.severity.INFO,
				message = "@" .. comment_author(comment) .. ": " .. comment_preview(comment),
				user_data = {
					github_comment_url = comment.html_url,
					github_comment = comment,
				},
			}
		end,
		vim.tbl_filter(function(comment)
			return type(comment) == "table" and type(comment.path) == "string" and type(comment.html_url) == "string"
		end, comments or {})
	)
end

local function root_dir(params)
	if params.root then
		return params.root
	end

	local ok, utils = pcall(require, "null-ls.utils")
	if ok and utils.get_root then
		local root = utils.get_root()
		if root then
			return root
		end
	end

	return (vim.uv or vim.loop).cwd()
end

local function cached_diagnostics(root)
	local cache = cache_by_root[root]
	if not cache then
		return nil
	end

	return build_diagnostics(root, cache.comments)
end

local function fetch_comments(params, done)
	local root = root_dir(params)
	if vim.fn.executable("gh") ~= 1 then
		return done(cached_diagnostics(root) or {})
	end

	run({ "gh", "pr", "view", "--json", "number", "-q", ".number" }, root, function(pr_result)
		if pr_result.code ~= 0 then
			cache_by_root[root] = nil
			return done({})
		end

		local pr_number = (pr_result.stdout or ""):match("%d+")
		if not pr_number then
			cache_by_root[root] = nil
			return done({})
		end

		run(
			{ "gh", "api", "repos/{owner}/{repo}/pulls/" .. pr_number .. "/comments", "--paginate", "--slurp" },
			root,
			function(comments_result)
				if comments_result.code ~= 0 then
					return done(cached_diagnostics(root) or {})
				end

				local decoded = decode_json(comments_result.stdout)
				if not decoded then
					return done(cached_diagnostics(root) or {})
				end

				local comments = flatten_pages(decoded)
				cache_by_root[root] = {
					comments = comments,
					fetched_at = os.time(),
					pr_number = pr_number,
					root = root,
				}

				return done(build_diagnostics(root, comments))
			end
		)
	end)
end

local function opener_command()
	local uname = (vim.uv or vim.loop).os_uname()
	if uname.sysname == "Darwin" then
		return "open"
	end

	return "xdg-open"
end

local function open_url(url)
	local opener = opener_command()
	if vim.fn.executable(opener) ~= 1 then
		vim.notify(opener .. " is not executable", vim.log.levels.WARN, { title = SOURCE })
		return
	end

	if vim.system then
		vim.system({ opener, url }, { detach = true })
		return
	end

	vim.fn.jobstart({ opener, url }, { detach = true })
end

local function github_diagnostics(params)
	local diagnostics = {}
	local start_row = params.range and params.range.row or params.row
	local end_row = params.range and params.range.end_row or params.row

	for row = start_row, end_row do
		vim.list_extend(diagnostics, vim.diagnostic.get(params.bufnr, { lnum = row - 1 }))
	end

	return vim.tbl_filter(function(diagnostic)
		return diagnostic.source == SOURCE
			and diagnostic.user_data
			and type(diagnostic.user_data.github_comment_url) == "string"
	end, diagnostics)
end

local function code_actions(params)
	local seen = {}

	return vim.tbl_map(
		function(diagnostic)
			local url = diagnostic.user_data.github_comment_url
			local comment = diagnostic.user_data.github_comment or {}
			local title = "Open GitHub comment in browser"
			local author = comment_author(comment)
			local preview = comment_preview(comment)

			if author ~= "unknown" or preview ~= "GitHub review comment" then
				title = title .. " (@" .. author .. ": " .. preview .. ")"
			end

			return {
				title = title,
				action = function()
					open_url(url)
				end,
			}
		end,
		vim.tbl_filter(function(diagnostic)
			local key = diagnostic.user_data.github_comment_url .. ":" .. diagnostic.lnum
			if seen[key] then
				return false
			end

			seen[key] = true
			return true
		end, github_diagnostics(params))
	)
end

function M.sources()
	local null_ls = require("null-ls")

	return {
		{
			name = SOURCE,
			method = { null_ls.methods.DIAGNOSTICS_ON_OPEN, null_ls.methods.DIAGNOSTICS_ON_SAVE },
			filetypes = {},
			generator = {
				async = true,
				multiple_files = true,
				fn = fetch_comments,
			},
		},
		{
			name = SOURCE .. "-actions",
			method = null_ls.methods.CODE_ACTION,
			filetypes = {},
			generator = {
				fn = code_actions,
			},
		},
	}
end

return M
