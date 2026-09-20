local M = {}

function M.add_dependency()
	local tasks = require("neoterm.task_panel").list_tasks()
	local function dependency_name(task)
		return table.concat(task.parts, "/")
	end
	vim.ui.select(tasks, {
		prompt = "Select dependency",
		format_item = dependency_name,
	}, function(task)
		if task == nil then
			return
		end

		local dependency = dependency_name(task)
		local yaml = require("neoterm.yaml")
		local frontmatter = yaml.read(0)
		local dependencies = frontmatter.dependencies
		if type(dependencies) == "string" then
			dependencies = { dependencies }
		elseif type(dependencies) ~= "table" or not vim.islist(dependencies) then
			dependencies = {}
		end
		table.insert(dependencies, dependency)
		frontmatter.dependencies = dependencies
		yaml.write(0, frontmatter)
	end)
end

function M.update_status()
	local yaml = require("neoterm.yaml")
	local remove = "REMOVE"
	local modes = require("neoterm.config").tasks.modes
	local statuses = {}
	local seen = {}
	local mode_names = vim.tbl_keys(modes)
	table.sort(mode_names)
	for _, mode in ipairs(mode_names) do
		for _, status in ipairs(modes[mode]) do
			if not seen[status] then
				seen[status] = true
				table.insert(statuses, status)
			end
		end
	end
	table.insert(statuses, remove)
	vim.ui.select(statuses, { prompt = "Select status" }, function(choice)
		if choice == nil then
			return
		end
		local frontmatter = yaml.read(0)
		if choice == remove then
			frontmatter.status = nil
		else
			frontmatter.status = choice
		end
		yaml.write(0, frontmatter)
	end)
end

return M
