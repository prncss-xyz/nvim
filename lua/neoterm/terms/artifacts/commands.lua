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

local function resolve_command(command, source, target, step, variant)
	local vars = {
		source = quoted_path(source),
		target = target and quoted_path(target) or nil,
		step = step,
		variant = variant,
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
		return apply_template(value, vars)
	end
	return resolve(command)
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
	local result = resolve_command(step.command, source, target, name, variant)
	if type(result) == "string" then
		result = { cmd = result }
	end
	assert(result.open == nil, "Use tag = 'open' instead of open")
	assert(result.tag == nil or result.tag == "open" or result.tag == "agent", "Unknown step command tag")
	assert(result.tag == nil or result.cmd == nil, "Tagged step commands cannot define cmd")
	if result.tag == "open" then
		assert(result.agent == nil and result.prompt == nil and result.skill == nil, "Open steps cannot define agent options")
	end
	result.cwd = result.cwd or cwd
	if step.fork == true or type(step.fork) == "string" then
		result.artifact_dir = vim.fs.dirname(source)
		result.artifact_source = source
	end
	return result
end

local function validate_step(step)
	assert(type(step.name) == "string", "Step name must be a string")
	assert(type(step.source) == "string", string.format("Step %s source must be a string", step.name))
	assert(
		step.target == nil or type(step.target) == "string",
		string.format("Step %s target must be a string", step.name)
	)
	assert(
		type(step.command) == "string" or type(step.command) == "table" or type(step.command) == "function",
		string.format("Step %s command must be a string, table, or function", step.name)
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

local function is_available(step, source, checkout_branch, related)
	local identity = paths.source(source, step.source)
	local target = step.target and vim.fs.joinpath(vim.fs.dirname(source), step.target) or nil
	return (
		paths.is_default(checkout_branch)
		or vim.tbl_contains(paths.branches(identity, { step }), checkout_branch)
		or related
	) and (target == nil or vim.fn.filereadable(target) == 0)
end

function M.for_file(opts)
	local definitions = {}
	local cwd = opts.cwd or vim.fn.getcwd()
	local relative = vim.fs.relpath(dirs.projects, vim.fs.abspath(cwd))
	local project = relative and paths.project(cwd) or nil
	local source = vim.fs.abspath(opts.file)
	local artifact_dir = project and vim.fs.joinpath(dirs.artifacts, project) or nil
	if artifact_dir == nil or vim.fs.relpath(artifact_dir, source) == nil or vim.fn.filereadable(source) == 0 then
		return definitions
	end

	local checkout_branch = paths.current_branch(cwd)
	local related = vim.tbl_contains(paths.checkouts(source), cwd)
	for _, step in ipairs(opts.steps or {}) do
		validate_step(step)
		if step_matches_source(step, source) and is_available(step, source, checkout_branch, related) then
			if step.variants then
				for _, variant in ipairs(step.variants) do
					table.insert(definitions, definition(step, source, cwd, variant))
				end
			else
				table.insert(definitions, definition(step, source, cwd))
			end
		end
	end
	add_task_executables(
		definitions,
		source,
		cwd,
		checkout_branch,
		related,
		require("neoterm.terms.artifacts.tasks").executables(vim.fs.dirname(source))
	)
	return definitions
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
		if definition_.tag == "open" then
			return require("neoterm.git").ensure_worktree(definition_.cwd, function(ok)
				if ok then
					if definition_.artifact_dir then
						require("neoterm.terms.artifacts.cwd").link(
							definition_.cwd,
							definition_.artifact_dir,
							definition_.artifact_source
						)
					end
					local path = require("neoterm.helpers.project_file").get_project_file(definition_.cwd)
						or vim.fs.joinpath(definition_.cwd, "README.md")
					config.create(vim.fn.fnameescape(path))
				end
			end)
		end
		definition_.key = definition_.name
		definition_.display_name = definition_.name
		definition_.exit_policy = definition_.exit_policy or "close"
		require("neoterm.terms").start(definition_)
	end)
end

return M
