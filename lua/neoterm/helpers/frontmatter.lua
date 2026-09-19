local M = {}

function M.add_dependency()
	local artifacts = require("my.parameters").dirs.artifacts
	local files = vim.tbl_filter(function(path)
		return vim.fs.basename(path) == "task.md"
	end, require("neoterm.artifact_tasks").files(artifacts))
	local function dependency_name(path)
		return assert(vim.fs.relpath(artifacts, path)):gsub("/task%.md$", "")
	end
	table.sort(files)
	vim.ui.select(files, {
		prompt = "Select dependency",
		format_item = dependency_name,
	}, function(path)
		if path == nil then
			return
		end

		local dependency = dependency_name(path)
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
	local statuses = vim.tbl_map(function(status)
		return status.name
	end, require("neoterm.config").status)
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
