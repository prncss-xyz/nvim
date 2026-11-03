local config = require("neoterm.config")
local dirs = config.dirs
local paths = require("neoterm.terms.artifacts.paths")

local M = {}

local function apply_template(t, vars)
	if type(t) == "function" then
		return t(vars)
	end
	return (string.gsub(t, "{(.-)}", function(key)
		return vars[key] or "{" .. key .. "}"
	end))
end

local function quoted_path(path)
	local home = vim.fs.normalize(vim.env.HOME)
	path = vim.fs.normalize(path)
	if path == home then
		path = "~"
	elseif vim.startswith(path, home .. "/") then
		path = "~" .. path:sub(#home + 1)
	end
	return '"' .. path .. '"'
end

local function resolve_command(command, source, target, step, name, variant, cwd)
	local vars = {
		source = quoted_path(source),
		target = target and quoted_path(target) or nil,
		step = step,
		name = name,
		variant = variant,
		message = vim.fs.dirname(source) ~= paths.project_artifacts(
			paths.artifact_project(source)
		) and paths.commit_message(vim.fs.joinpath(vim.fs.dirname(source), "task.md")) or nil,
	}
	local function resolve(value)
		if type(value) == "function" then
			return resolve(apply_template(value, vars))
		end
		if type(value) == "table" then
			local result = {}
			for key, item in pairs(value) do
				result[key] = resolve(item)
			end
			return result
		end
		if type(value) ~= "string" then
			return value
		end
		if target == nil then
			assert(not value:find("{target}", 1, true), "Step command references {target} without defining target")
		end
		if value:find("{branch}", 1, true) then
			vars.branch = assert(paths.current_branch(cwd), "Cannot determine current branch")
		end
		if value:find("{source_branch}", 1, true) then
			for _, branch in ipairs(config.default_branches) do
				vim.fn.system({ "git", "-C", cwd, "show-ref", "--verify", "--quiet", "refs/heads/" .. branch })
				if vim.v.shell_error == 0 then
					vars.source_branch = branch
					break
				end
			end
			assert(rawget(vars, "source_branch"), "Cannot determine default branch")
		end
		return apply_template(value, vars)
	end
	setmetatable(vars, {
		__index = function(_, key)
			if key == "source_branch" then
				return resolve("{source_branch}")
			end
		end,
	})
	return resolve(command), vars
end

local function build_step(step, source, target, current_cwd, name, variant)
	source = vim.fs.abspath(source)
	target = target and vim.fs.abspath(target) or nil
	local cwd = current_cwd
	if step.fork == true or type(step.fork) == "string" then
		local identity = paths.source(source, step.source)
		local branch = paths.branch(identity, step.fork, { variant = variant, step = name })
		cwd = paths.checkout(identity.project, branch)
	end
	local result, vars = resolve_command(step.command, source, target, name, step.name, variant, current_cwd)
	vars.cwd = cwd
	if step.command == nil then
		result = {}
	end
	if type(result) == "string" then
		result = { cmd = result }
	end
	assert(result.open == nil, "Use tag = 'open' instead of open")
	assert(result.tag == nil or result.tag == "open" or result.tag == "agent", "Unknown step command tag")
	assert(result.tag == nil or result.cmd == nil, "Tagged step commands cannot define cmd")
	if result.tag == "open" then
		assert(
			result.agent == nil and result.prompt == nil and result.skill == nil,
			"Open steps cannot define agent options"
		)
	end
	result.cwd = result.cwd or cwd
	if step.on_success then
		result.on_success = function(output)
			step.on_success(vars, output)
		end
	end
	if step.fork == true or type(step.fork) == "string" then
		result.artifact_dir = vim.fs.dirname(source)
		result.artifact_source = source
	end
	return result
end

local function validate_step(step)
	assert(type(step.name) == "string", "Step name must be a string")
	assert(step.on_success == nil or type(step.on_success) == "function", "Step on_success must be a function")
	assert(step.auto == nil or vim.islist(step.auto), string.format("Step %s auto must be an array", step.name))
	for _, name in ipairs(step.auto or {}) do
		assert(type(name) == "string", string.format("Step %s auto values must be strings", step.name))
	end
	if step.status ~= nil then
		assert(
			require("neoterm.terms.artifacts.statuses").order()[step.status],
			string.format("Step %s status must be an enabled task status", step.name)
		)
	end
	for _, key in ipairs({ "source", "target" }) do
		local value = step[key]
		if value ~= nil then
			assert(type(value) == "string" or type(value) == "table", "Step " .. key .. " must be a string or array")
			if type(value) == "table" then
				assert(vim.islist(value) and #value > 0, "Step " .. key .. " must be a nonempty array")
				for _, name in ipairs(value) do
					assert(type(name) == "string", "Step " .. key .. " values must be strings")
				end
			end
		end
	end
	assert(
		step.command == nil
			or type(step.command) == "string"
			or type(step.command) == "table"
			or type(step.command) == "function",
		string.format("Step %s command must be a string, table, function, or nil", step.name)
	)
	assert(
		step.variants == nil or type(step.variants) == "table",
		string.format("Step %s variants must be a table", step.name)
	)
	for _, variant in ipairs(step.variants or {}) do
		assert(type(variant) == "string", string.format("Step %s variants must be strings", step.name))
	end
end

local function definition(step, source, cwd, variant)
	local identity = paths.source(source, step.source)
	local target = step.target and vim.fs.joinpath(identity.folder, step.target) or nil
	local name = paths.step_name(identity, step, variant)
	local task = build_step(step, source, target, cwd, name, variant)
	task.name = name
	return task
end

local function executable_definition(path, cwd)
	local relative = assert(vim.fs.relpath(dirs.artifacts, path), "Executable must be inside the artifact directory")
	local name = "script:" .. vim.fs.dirname(relative) .. " " .. vim.fs.basename(relative)
	return { name = name, cmd = { path }, cwd = cwd, exit_policy = "keep" }
end

local function add_task_executables(definitions, task_source, cwd, checkout_branch, related, executables)
	if vim.fs.basename(task_source) ~= "task.md" then
		return
	end
	if
		not related
		and not paths.is_default(checkout_branch)
		and not vim.tbl_contains(paths.branches(paths.source(task_source, "task.md")), checkout_branch)
	then
		return
	end
	local task_dir = vim.fs.dirname(task_source)
	for _, path in ipairs(executables) do
		if vim.fs.dirname(path) == task_dir then
			table.insert(definitions, executable_definition(path, cwd))
		end
	end
end

local function step_matches_source(step, source)
	local filename = vim.fs.basename(source)
	return filename == step.source or (step.target == nil and vim.endswith(filename, "." .. step.source))
end

local function task_file(identity)
	if vim.fs.basename(identity.file) == identity.source then
		return vim.fs.joinpath(identity.folder, "task.md")
	end
	return vim.fs.joinpath(identity.folder, identity.identifier .. ".task.md")
end

local function status_reached(step, identity)
	if step.status == nil then
		return true
	end
	local order = require("neoterm.terms.artifacts.statuses").order()
	local status = require("neoterm.terms.artifacts.tasks").status(task_file(identity))
	return not (status and order[status] and order[status] < order[step.status])
end

local function is_available(step, source, checkout_branch, related)
	local identity = paths.source(source, step.source)
	if not status_reached(step, identity) then
		return false
	end
	return paths.is_default(checkout_branch)
		or vim.tbl_contains(paths.branches(identity, { step }), checkout_branch)
		or related
end

local function context(opts)
	local cwd = opts.cwd or vim.fn.getcwd()
	local relative = vim.fs.relpath(dirs.projects, vim.fs.abspath(cwd))
	local project = relative and paths.project(cwd) or nil
	local source = vim.fs.abspath(opts.file)
	local artifact_dir = project and vim.fs.joinpath(dirs.artifacts, project) or nil
	if artifact_dir == nil or vim.fs.relpath(artifact_dir, source) == nil or vim.fn.filereadable(source) == 0 then
		return nil
	end
	return {
		cwd = cwd,
		source = source,
		checkout_branch = paths.current_branch(cwd),
		related = vim.tbl_contains(paths.checkouts(source), cwd),
	}
end

local function available_step(configured_step, ctx, ignore_targets)
	validate_step(configured_step)
	local source = ctx.source
	local sources = type(configured_step.source) == "table" and configured_step.source or { configured_step.source }
	local matches = configured_step.source == nil
	for _, name in ipairs(sources) do
		matches = matches or step_matches_source({ source = name, target = configured_step.target }, source)
	end
	if not matches then
		return nil
	end
	local step = vim.deepcopy(configured_step)
	local selected_source = configured_step.source == nil and source or nil
	for _, name in ipairs(sources) do
		local candidate = vim.fs.joinpath(vim.fs.dirname(source), name)
		if step_matches_source({ source = name, target = step.target }, source) then
			candidate = source
		end
		if vim.fn.filereadable(candidate) == 1 then
			step.source = name
			selected_source = candidate
		end
	end
	local targets = type(step.target) == "table" and step.target or { step.target }
	local blocked = false
	if not ignore_targets then
		for _, name in ipairs(targets) do
			blocked = blocked or vim.fn.filereadable(vim.fs.joinpath(vim.fs.dirname(source), name)) == 1
		end
	end
	step.target = targets[1]
	if selected_source and not blocked and is_available(step, selected_source, ctx.checkout_branch, ctx.related) then
		return step, selected_source
	end
end

function M.for_file(opts)
	local definitions = {}
	local ctx = context(opts)
	if ctx == nil then
		return definitions
	end
	for _, configured_step in ipairs(opts.steps or {}) do
		local step, selected_source = available_step(configured_step, ctx, opts.ignore_targets)
		if step then
			for _, variant in ipairs(step.variants or { false }) do
				table.insert(definitions, definition(step, selected_source, ctx.cwd, variant or nil))
			end
		end
	end

	if opts.executables == false then
		return definitions
	end
	add_task_executables(
		definitions,
		ctx.source,
		ctx.cwd,
		ctx.checkout_branch,
		ctx.related,
		require("neoterm.terms.artifacts.tasks").executables(vim.fs.dirname(ctx.source))
	)
	return definitions
end

---Whether `step` with `variant` would be offered for `opts.file` from `opts.cwd`, without building it.
---@param opts { cwd?: string, file: string, step: table, variant?: string }
---@return boolean
function M.is_enabled(opts)
	local ctx = context(opts)
	if ctx == nil or available_step(opts.step, ctx) == nil then
		return false
	end
	if opts.variant == nil then
		return opts.step.variants == nil
	end
	return vim.tbl_contains(opts.step.variants or {}, opts.variant)
end

function M.run(definition)
	if definition.tag == nil and definition.cmd == nil then
		if definition.on_success then
			definition.on_success()
		end
		return
	end
	if definition.tag == "open" then
		return require("neoterm.git").ensure_worktree(definition.cwd, function(ok)
			if ok then
				if definition.artifact_dir then
					require("neoterm.terms.artifacts.cwd").link(
						definition.cwd,
						definition.artifact_dir,
						definition.artifact_source
					)
				end
				local path = require("neoterm.helpers.project_file").get_project_file(definition.cwd)
					or vim.fs.joinpath(definition.cwd, "README.md")
				config.create(vim.fn.fnameescape(path))
			end
		end)
	end
	definition.key = definition.name
	definition.display_name = definition.name
	definition.exit_policy = definition.exit_policy or "close"
	require("neoterm.terms").start(definition)
end

function M.select_for_current_file(resume)
	local file = vim.api.nvim_buf_get_name(0)
	local cwd = require("neoterm.terms.artifacts.cwd").context_dir() or vim.fn.getcwd()
	local steps = config.steps
	if resume then
		steps = vim.tbl_filter(function(step)
			return type(step.command) == "table" and step.command.tag == "agent"
		end, steps)
	end
	local definitions = M.for_file({
		cwd = cwd,
		file = file,
		steps = steps,
		ignore_targets = resume,
	})
	if not resume and vim.fn.filereadable(file) == 1 and vim.fn.executable(file) == 1 then
		table.insert(definitions, { name = "exec", cmd = { vim.fs.abspath(file) }, cwd = cwd })
	end
	if resume then
		definitions = vim.tbl_filter(function(item)
			return item.tag == "agent"
		end, definitions)
		for index, item in ipairs(definitions) do
			definitions[index] = {
				tag = item.tag,
				title = item.title,
				agent = item.agent,
				resume = true,
				name = item.name,
				cwd = item.cwd,
				artifact_dir = item.artifact_dir,
				artifact_source = item.artifact_source,
			}
		end
	end
	vim.ui.select(definitions, {
		prompt = resume and "Resume Buffer Step: " or "Start Buffer Step: ",
		format_item = function(definition_)
			return definition_.name
		end,
	}, function(definition_)
		if definition_ == nil then
			return
		end
		M.run(definition_)
	end)
end

return M
