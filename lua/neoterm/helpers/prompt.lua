local M = {}

function M.with_prompt(cb)
	return function(input, prompt)
		input(prompt, function(contents)
			cb(contents, prompt)
		end)
	end
end

function M.create_task(remove, directory, project_root)
	return function(input, prompt)
		local artifact_cwd = require("neoterm.terms.artifact_cwd")
		local harness = require("neoterm.harness")
		local current = vim.api.nvim_buf_get_name(0)
		local root = project_root or artifact_cwd.resolve(current) or vim.fs.root(0, ".git") or vim.uv.cwd()

		local function get_task(target)
			input(prompt, function(contents, using_selection)
				if remove and using_selection then
					vim.cmd.normal({ 'gv"_d', bang = true })
				end
				harness.create_artifact(contents, "task.md", root, target)
			end)
		end

		if directory then
			get_task(directory)
		else
			harness.select_artifact_directory(root, get_task)
		end
	end
end

function M.sender(prefix)
	return function(input, prompt, new_agent, query)
		input(prompt, function(contents)
			require("neoterm.terms").put(
				query or { tag = "agent" },
				(prefix or prompt) .. " " .. contents,
				{ new = new_agent }
			)
		end)
	end
end

return M
